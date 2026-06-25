# frozen_string_literal: true

require_relative "factory_aggregation"
require_relative "formatting"

module RSpecTelemetry
  class Summary
    ExampleStat = Struct.new(
      :example_id,
      :file_path,
      :line_number,
      :duration_ms,
      :factory_bot_total_ms,
      :factory_bot_count
    )

    def initialize(config)
      @config = config
      @factory_acc = FactoryAggregation::Accumulator.new
      @examples = {}
    end

    def add(event)
      case event[:type]
      when "factory_bot.run_factory"
        add_factory(event)
      when "example.finished"
        add_example(event)
      end
    end

    def factories
      @factory_acc.stats
    end

    def examples
      @examples.values
    end

    def top_factories(limit = @config.summary_limit)
      @factory_acc.top(limit)
    end

    def slow_examples(limit = @config.summary_limit)
      sorted = examples.sort_by { |e| -e.duration_ms.to_f }
      threshold = @config.slow_example_threshold_ms
      sorted = sorted.select { |e| e.duration_ms.to_f >= threshold } if threshold
      sorted.first(limit)
    end

    private

    def add_factory(event)
      self_ms = (event[:self_duration_ms] || event[:duration_ms]).to_f
      @factory_acc.add(
        factory: event[:factory],
        strategy: event[:strategy],
        duration_ms: event[:duration_ms],
        self_duration_ms: self_ms
      )

      example_id = event[:example_id]
      return unless example_id

      ex = (@examples[example_id] ||= ExampleStat.new(example_id, nil, nil, nil, 0.0, 0))
      ex.factory_bot_total_ms += self_ms
      ex.factory_bot_count += 1
    end

    def add_example(event)
      example_id = event[:example_id]
      return unless example_id

      ex = (@examples[example_id] ||= ExampleStat.new(example_id, nil, nil, nil, 0.0, 0))
      ex.file_path = event[:file_path]
      ex.line_number = event[:line_number]
      ex.duration_ms = event[:duration_ms]
    end
  end

  module SummaryPrinter
    module_function

    def print(summary, config, io = config.summary_io)
      return unless config.print_summary

      lines = []
      lines.concat(factory_section(summary, config))
      lines.concat(example_section(summary, config))
      return if lines.empty?

      io.puts
      io.puts(lines.join("\n"))
    rescue => e
      warn("[rspec-telemetry] failed to print summary: #{e.class}: #{e.message}")
    end

    def factory_section(summary, _config)
      tops = summary.top_factories
      return [] if tops.empty?

      lines = ["FactoryBot telemetry summary", "", "Top factories by self time (子factoryを除く):", ""]
      tops.each_with_index do |f, i|
        lines << "#{i + 1}. #{f.key}"
        lines << "   count: #{f.count}"
        lines << "   self_total: #{Formatting.fixed(f.self_total_ms)}ms"
        lines << "   total: #{Formatting.fixed(f.total_ms)}ms"
        lines << "   avg: #{Formatting.fixed(f.avg_ms)}ms"
        lines << "   max: #{Formatting.fixed(f.max_ms)}ms"
        lines << ""
      end

      lines
    end

    def example_section(summary, _config)
      slow = summary.slow_examples
      return [] if slow.empty?

      lines = ["Slow examples:", ""]
      slow.each_with_index do |e, i|
        lines << "#{i + 1}. #{e.example_id}"
        lines << "   duration: #{Formatting.fixed(e.duration_ms)}ms"
        lines << "   factory_bot_total: #{Formatting.fixed(e.factory_bot_total_ms)}ms (#{e.factory_bot_count} calls)"
        lines << ""
      end

      lines
    end
  end
end
