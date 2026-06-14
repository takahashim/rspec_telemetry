# frozen_string_literal: true

require_relative "ndjson"
require_relative "factory_aggregation"

module RSpecTelemetry
  class Analyzer
    Example = Struct.new(
      :example_id,
      :file_path,
      :line_number,
      :full_description,
      :status,
      :duration_ms,
      :fb_self_total_ms,
      :fb_count,
      keyword_init: true
    )

    FileStat = Struct.new(:file_path, :example_count, :duration_ms, keyword_init: true)

    attr_reader(
      :examples,
      :files,
      :example_count,
      :failure_count,
      :pending_count,
      :suite_duration_ms
    )

    def initialize
      @examples = {}
      @factory_acc = FactoryAggregation::Accumulator.new
      @files = {}
      # Factory events arrive before example.finished, so merge them after loading.
      @example_fb = Hash.new { |h, k| h[k] = [0.0, 0] }
      @example_count = 0
      @failure_count = 0
      @pending_count = 0
      @suite_duration_ms = 0.0
    end

    def self.load(paths)
      new.tap do |analyzer|
        Array(paths).each do |path|
          File.foreach(path) do |line|
            event = Ndjson.parse(line)
            analyzer.add(event) if event
          end
        end
      end
    end

    def add(event)
      case event["type"]
      when "example.finished"
        add_example(event)
      when "factory_bot.run_factory"
        add_factory(event)
      when "suite.finished"
        add_suite(event)
      end
    end

    def total_example_ms
      @examples.values.sum { |e| e.duration_ms.to_f }
    end

    def factories
      @factory_acc.stats
    end

    def total_factory_self_ms
      @factory_acc.stats.sum(&:self_total_ms)
    end

    def factory_time_ratio
      total = total_example_ms
      total.zero? ? 0.0 : total_factory_self_ms / total
    end

    def slow_examples(limit = 20)
      merged_examples.sort_by { |e| -e.duration_ms.to_f }.first(limit)
    end

    def merged_examples
      # Mutate the report structs at the read boundary; raw aggregates stay separate.
      @examples.values.map do |ex|
        self_total, count = @example_fb[ex.example_id]
        ex.fb_self_total_ms = self_total
        ex.fb_count = count
        ex
      end
    end

    def top_factories(limit = 20)
      @factory_acc.top(limit)
    end

    def slow_files(limit = 20)
      @files.values.sort_by { |f| -f.duration_ms.to_f }.first(limit)
    end

    def self.events_for_example(paths, example_id)
      events = []
      Array(paths).each do |path|
        File.foreach(path) do |line|
          event = Ndjson.parse(line)
          next unless event && event["example_id"] == example_id

          events << event
        end
      end

      events
    end

    private

    def add_example(event)
      id = event["example_id"] || event["full_description"]
      ex = (@examples[id] ||= Example.new(
        example_id: id,
        file_path: event["file_path"],
        line_number: event["line_number"],
        full_description: event["full_description"],
        status: event["status"],
        duration_ms: 0.0,
        fb_self_total_ms: 0.0,
        fb_count: 0
      ))
      ex.duration_ms = event["duration_ms"]
      ex.status = event["status"]
      ex.file_path ||= event["file_path"]
      ex.line_number ||= event["line_number"]
      ex.full_description ||= event["full_description"]

      file = event["file_path"]
      return unless file

      fs = (@files[file] ||= FileStat.new(file_path: file, example_count: 0, duration_ms: 0.0))
      fs.example_count += 1
      fs.duration_ms += event["duration_ms"].to_f
    end

    def add_factory(event)
      self_ms = (event["self_duration_ms"] || event["duration_ms"]).to_f
      @factory_acc.add(
        factory: event["factory"],
        strategy: event["strategy"],
        duration_ms: event["duration_ms"],
        self_duration_ms: self_ms
      )

      id = event["example_id"]
      return unless id

      acc = @example_fb[id]
      acc[0] += self_ms
      acc[1] += 1
    end

    def add_suite(event)
      @example_count += event["example_count"].to_i
      @failure_count += event["failure_count"].to_i
      @pending_count += event["pending_count"].to_i
      @suite_duration_ms += event["duration_ms"].to_f
    end
  end
end
