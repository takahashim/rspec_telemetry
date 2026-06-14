# frozen_string_literal: true

require_relative "document"
require_relative "format"

module RSpecTelemetry
  module Trace
    module Viewer
      module Label
        Segment = Data.define(:text, :style)

        def self.segments(entry)
          return action_segments(entry) if entry.is_a?(Document::Action)

          event_segments(entry)
        end

        def self.plain(entry) = segments(entry).map(&:text).join

        def self.category(entry)
          if entry.is_a?(Document::Action)
            return failed?(entry.status) ? :error : :action
          end

          case entry.op
          when "factory"
            entry.fields["depth"].to_i.positive? ? :dim : :plain
          else
            :plain
          end
        end

        def self.action_segments(action)
          tag = failed?(action.status) ? " [#{action.status.upcase}]" : ""
          style = failed?(action.status) ? :error : :action
          segments = [seg("EXAMPLE #{action.label}#{tag}", style)]
          segments << seg("  at: #{action.source}", :dim) if action.source
          segments
        end

        def self.event_segments(event)
          case event.op
          when "factory"
            factory_segments(event.fields)
          else
            [seg("#{event.op.upcase} #{compact(extra(event.fields))}", :plain)]
          end
        end

        def self.factory_segments(fields)
          depth = fields["depth"].to_i
          style = depth.positive? ? :dim : :plain
          [seg("#{"  " * depth}FACTORY #{name(fields)}#{traits(fields["traits"])}  #{timing(fields)}", style)]
        end

        def self.name(fields) = "#{fields["factory"]}:#{fields["strategy"]}"

        def self.timing(fields)
          total = Format.ms(fields["duration_ms"])
          self_ms = fields["self_duration_ms"]
          return total.to_s unless self_ms && self_ms != fields["duration_ms"]

          "#{total} (self #{Format.ms(self_ms)})"
        end

        def self.traits(list)
          list.nil? || list.empty? ? "" : " [#{Array(list).join(",")}]"
        end

        def self.failed?(status) = %w[failed error].include?(status)

        def self.extra(fields)
          fields.reject { |key, _| Document::INFRA_FIELDS.include?(key) }
        end

        def self.seg(text, style) = Segment.new(text: text, style: style)

        def self.compact(value)
          return "" if value.nil? || value.empty?
          return inspect_hash(value) if value.is_a?(Hash)

          value.inspect
        end

        # Format a Hash deterministically so output does not depend on the Ruby
        # version (Ruby 3.4 changed Hash#inspect from `{"k"=>v}` to `{"k" => v}`).
        def self.inspect_hash(hash)
          "{#{hash.map { |key, val| "#{key.inspect} => #{val.inspect}" }.join(", ")}}"
        end
      end
    end
  end
end
