# frozen_string_literal: true

require_relative "ndjson"
require_relative "factory_aggregation"

module RSpecTelemetry
  class FactoryComparison
    Row = Struct.new(
      :label,
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

    attr_reader :before_path, :after_path, :all_depths, :by_factory

    def initialize(before_path, after_path, all_depths: false, by_factory: false)
      @before_path = before_path
      @after_path = after_path
      @all_depths = all_depths
      @by_factory = by_factory
    end

    def duration_label
      all_depths ? "Self(ms)" : "Total(ms)"
    end

    def rows
      before = aggregate(before_path)
      after = aggregate(after_path)

      (before.keys | after.keys).sort.map do |key|
        before_stat = before[key]
        after_stat = after[key]

        Row.new(
          label: key,
          before_count: before_stat&.count || 0,
          after_count: after_stat&.count || 0,
          before_duration_ms: duration_for(before_stat),
          after_duration_ms: duration_for(after_stat)
        )
      end
    end

    private

    # Reuse the shared accumulator so counts, durations, and the factory:strategy
    # granularity stay identical to the live summary, CLI report, and viewer.
    # create and build are kept as separate keys (e.g. "user:create") unless
    # by_factory rolls every strategy up under the bare factory name.
    def aggregate(path)
      acc = FactoryAggregation::Accumulator.new

      File.foreach(path) do |line|
        event = Ndjson.parse(line)
        next unless factory_event?(event)

        acc.add(
          factory: event["factory"],
          strategy: event["strategy"],
          duration_ms: event["duration_ms"],
          self_duration_ms: event["self_duration_ms"]
        )
      end

      stats = by_factory ? merge_by_factory(acc.stats) : acc.stats
      stats.to_h { |stat| [stat.key, stat] }
    end

    # Collapse create/build/etc. into a single row keyed by the factory name.
    def merge_by_factory(stats)
      stats.group_by(&:factory).map do |factory, group|
        FactoryAggregation::Stat.new(
          key: factory,
          factory: factory,
          strategy: nil,
          count: group.sum(&:count),
          total_ms: group.sum(&:total_ms),
          self_total_ms: group.sum(&:self_total_ms),
          max_ms: group.map(&:max_ms).max
        )
      end
    end

    def factory_event?(event)
      return false unless event
      return false unless event["type"] == "factory_bot.run_factory"
      return true if all_depths

      event["depth"].to_i.zero?
    end

    # Default mode compares inclusive time on root events; --all-depths compares
    # self time so nested children are not double-counted.
    def duration_for(stat)
      return 0.0 unless stat

      all_depths ? stat.self_total_ms : stat.total_ms
    end
  end
end
