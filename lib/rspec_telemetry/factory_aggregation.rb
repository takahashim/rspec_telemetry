# frozen_string_literal: true

module RSpecTelemetry
  module FactoryAggregation
    # Shared by live summaries, CLI reports, and the viewer so ranking rules stay
    # identical. A Struct (not Data) so collection runs on Ruby 3.1, where this is
    # on the require path via summary.rb.
    Stat = Struct.new(:key, :factory, :strategy, :count, :total_ms, :self_total_ms, :max_ms, keyword_init: true) do
      def avg_ms = count.zero? ? 0.0 : total_ms / count
    end

    class Accumulator
      def initialize
        @rows = {}
      end

      def add(factory:, strategy:, duration_ms:, self_duration_ms: nil)
        key = "#{factory}:#{strategy}"
        total = duration_ms.to_f
        self_ms = (self_duration_ms || duration_ms).to_f
        row = (@rows[key] ||= {factory: factory, strategy: strategy, count: 0, total: 0.0, self: 0.0, max: 0.0})
        row[:count] += 1
        row[:total] += total
        row[:self] += self_ms
        row[:max] = total if total > row[:max]
        self
      end

      def stats
        @rows.map do |key, row|
          Stat.new(
            key: key,
            factory: row[:factory],
            strategy: row[:strategy],
            count: row[:count],
            total_ms: row[:total],
            self_total_ms: row[:self],
            max_ms: row[:max]
          )
        end
      end

      def top(limit = nil)
        # Rank by self time so nested factories are not double-counted.
        ranked = stats.sort_by { |stat| -stat.self_total_ms }
        limit ? ranked.first(limit) : ranked
      end
    end
  end
end
