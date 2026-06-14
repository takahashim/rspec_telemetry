# frozen_string_literal: true

require_relative "document"
require_relative "format"
require_relative "../../factory_aggregation"

module RSpecTelemetry
  module Trace
    module Viewer
      module ReportView
        Row = Data.define(:text, :style, :source, :payload)

        TITLES = {examples: "slowest examples", factories: "factories by self time"}.freeze

        def self.title(view) = TITLES[view]

        def self.rows(document, view)
          case view
          when :examples
            example_rows(document)
          when :factories
            factory_rows(document)
          else
            []
          end
        end

        def self.example_rows(document)
          document.actions.sort_by { |action| -(action.duration_ms || 0.0) }.map do |action|
            failed = %w[failed error].include?(action.status)
            tag = failed ? " [#{action.status.upcase}]" : ""
            Row.new(
              text: "#{dur(action.duration_ms)}  #{action.label}#{tag}",
              style: failed ? :error : :plain,
              source: action.source,
              payload: action
            )
          end
        end

        def self.factory_rows(document)
          aggregate(document).top.map do |stat|
            Row.new(
              text: "#{dur(stat.self_total_ms)}  #{stat.key}  ×#{stat.count}  total #{Format.ms(stat.total_ms)}",
              style: :plain,
              source: nil,
              payload: stat
            )
          end
        end

        def self.detail(payload)
          return [] unless payload.is_a?(FactoryAggregation::Stat)

          [
            "FACTORY #{payload.key}",
            "",
            "count: #{payload.count}",
            "self total: #{Format.ms(payload.self_total_ms)}  (children excluded)",
            "total: #{Format.ms(payload.total_ms)}  (children included)",
            "avg: #{Format.ms(payload.avg_ms)}",
            "max: #{Format.ms(payload.max_ms)}"
          ]
        end

        def self.aggregate(document)
          acc = FactoryAggregation::Accumulator.new
          document.events.each do |event|
            next unless event.op == "factory"

            fields = event.fields
            acc.add(
              factory: fields["factory"],
              strategy: fields["strategy"],
              duration_ms: fields["duration_ms"],
              self_duration_ms: fields["self_duration_ms"]
            )
          end

          acc
        end

        def self.dur(ms) = (Format.ms(ms) || "-").rjust(8)
      end
    end
  end
end
