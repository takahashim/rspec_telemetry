# frozen_string_literal: true

require_relative "ndjson"

module RSpecTelemetry
  class FactoryComparison
    FactoryStat = Struct.new(:count, :duration_ms)
    Row = Struct.new(
      :factory,
      :before_count,
      :after_count,
      :before_duration_ms,
      :after_duration_ms,
      keyword_init: true
    ) do
      def count_diff
        after_count - before_count
      end

      def duration_diff_ms
        after_duration_ms - before_duration_ms
      end

      def count_change_percent
        change_percent(before_count, after_count)
      end

      def duration_change_percent
        change_percent(before_duration_ms, after_duration_ms)
      end

      private

      def change_percent(before_value, after_value)
        return nil if before_value.zero?

        ((after_value - before_value) / before_value.to_f) * 100
      end
    end

    attr_reader :before_path, :after_path, :all_depths

    def initialize(before_path, after_path, all_depths: false)
      @before_path = before_path
      @after_path = after_path
      @all_depths = all_depths
    end

    def rows
      before = aggregate(before_path)
      after = aggregate(after_path)

      (before.keys | after.keys).sort.map do |factory|
        before_stat = before.fetch(factory, empty_stat)
        after_stat = after.fetch(factory, empty_stat)

        Row.new(
          factory: factory,
          before_count: before_stat.count,
          after_count: after_stat.count,
          before_duration_ms: before_stat.duration_ms,
          after_duration_ms: after_stat.duration_ms
        )
      end
    end

    private

    def aggregate(path)
      stats = Hash.new { |hash, factory| hash[factory] = FactoryStat.new(0, 0.0) }

      File.foreach(path) do |line|
        event = Ndjson.parse(line)
        next unless factory_event?(event)

        stat = stats[event["factory"].to_s]
        stat.count += 1
        stat.duration_ms += duration_ms(event)
      end

      stats
    end

    def factory_event?(event)
      return false unless event
      return false unless event["type"] == "factory_bot.run_factory"
      return true if all_depths

      event["depth"].to_i.zero?
    end

    def duration_ms(event)
      key = all_depths ? "self_duration_ms" : "duration_ms"
      event[key].to_f
    end

    def empty_stat
      FactoryStat.new(0, 0.0)
    end
  end
end
