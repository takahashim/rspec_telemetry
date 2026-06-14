# frozen_string_literal: true

require_relative "../../ndjson"

module RSpecTelemetry
  module Trace
    module Viewer
      # Incrementally folds an NDJSON trace into examples and their child events.
      class Document
        Action = Data.define(:seq, :verb, :label, :t, :source, :wall_ms, :status, :duration_ms, :exception)

        Event = Data.define(:seq, :op, :t, :action, :fields)

        # Hidden from generic labels/details; the original fields remain on each event.
        INFRA_FIELDS = %w[type seq op action wall_ms t timestamp monotonic_time pid thread_id].freeze

        attr_reader(
          :entries,
          :version,
          :level,
          :metadata,
          :wall_time,
          :failed_action,
          :end_wall_ms,
          :example_count,
          :failure_count,
          :pending_count
        )

        def self.from_lines(lines)
          lines.each_with_object(new) { |line, doc| doc.apply(line) }
        end

        def initialize
          @entries = []
          @actions_by_seq = {}
          @action_by_example = {}
          @current_action = nil
          @seq = -1
          @t0 = nil
          @started = false
          @ended = false
          @status = nil
        end

        # Unknown future event types are kept as generic events instead of dropped.
        def apply(line)
          parsed = parse(line)
          return self unless parsed.is_a?(Hash)

          @started = true
          set_origin(parsed)

          case parsed["type"]
          when nil
            self
          when "example.started"
            open_action(parsed)
          when "example.finished"
            close_action(parsed)
          when "factory_bot.run_factory"
            record("factory", parsed)
          when "suite.finished"
            finish(parsed)
          else
            record(parsed["type"], parsed)
          end

          self
        end

        def events = @entries.grep(Event)

        def actions = @entries.grep(Action)

        def action(seq) = @actions_by_seq[seq]

        def events_for(action_seq)
          @entries.select { |entry| entry.is_a?(Event) && entry.action == action_seq }
        end

        def pending? = @started && !@ended

        def status
          return @status if @status
          return "ok" if @ended

          "pending"
        end

        private

        def parse(line) = Ndjson.parse(line)

        # Normalize each process-local monotonic clock to t=0 for display.
        def set_origin(parsed)
          @t0 ||= parsed["monotonic_time"]
        end

        def wall_ms_of(parsed)
          mono = parsed["monotonic_time"]
          return nil if mono.nil? || @t0.nil?

          ((mono - @t0) * 1000.0).round(3)
        end

        def next_seq = (@seq += 1)

        def open_action(parsed)
          wall = wall_ms_of(parsed)
          mark_wall(wall)
          action = Action.new(
            seq: next_seq,
            verb: "example",
            label: parsed["full_description"] || parsed["example_id"] || "(example)",
            t: parsed["t"],
            source: source_of(parsed),
            wall_ms: wall,
            status: nil,
            duration_ms: nil,
            exception: nil
          )
          @entries << action
          @actions_by_seq[action.seq] = action
          @action_by_example[parsed["example_id"]] = action.seq if parsed["example_id"]
          @current_action = action.seq
        end

        # Data objects are immutable, so finishing an example replaces its entry.
        def close_action(parsed)
          mark_wall(wall_ms_of(parsed))
          seq = @action_by_example[parsed["example_id"]]
          old = seq && @actions_by_seq[seq]
          return if old.nil?

          updated = old.with(
            status: parsed["status"],
            duration_ms: parsed["duration_ms"],
            exception: exception_of(parsed)
          )
          @actions_by_seq[seq] = updated
          @failed_action = seq if failed_status?(parsed["status"])
          index = @entries.index(old)
          @entries[index] = updated if index
        end

        def record(op, parsed)
          wall = wall_ms_of(parsed)
          mark_wall(wall)
          owner = @action_by_example[parsed["example_id"]] || @current_action
          event = Event.new(
            seq: next_seq,
            op: op,
            t: parsed["t"],
            action: owner,
            fields: parsed.merge("wall_ms" => wall)
          )
          @entries << event
        end

        def finish(parsed)
          @ended = true
          @example_count = parsed["example_count"]
          @failure_count = parsed["failure_count"]
          @pending_count = parsed["pending_count"]
          @status = parsed["failure_count"].to_i.positive? ? "failed" : "ok"
          mark_wall(wall_ms_of(parsed))
        end

        def mark_wall(wall)
          return if wall.nil?

          @end_wall_ms = wall if @end_wall_ms.nil? || wall > @end_wall_ms
        end

        def source_of(parsed)
          file = parsed["file_path"]
          return nil if file.nil?

          line = parsed["line_number"]
          line ? "#{file}:#{line}" : file
        end

        def exception_of(parsed)
          klass = parsed["exception_class"]
          return nil if klass.nil?

          {"class" => klass, "message" => parsed["exception_message"]}
        end

        def failed_status?(status) = %w[failed error].include?(status)
      end
    end
  end
end
