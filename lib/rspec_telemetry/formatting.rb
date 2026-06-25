# frozen_string_literal: true

module RSpecTelemetry
  # Single source of truth for how telemetry numbers are rendered, so the decimal
  # places, sign convention, and ms/s threshold stay consistent across the console
  # report, the comparison table, and the live summary.
  module Formatting
    module_function

    # Human-friendly duration: seconds past 1000ms, otherwise milliseconds.
    def duration(ms)
      ms = ms.to_f
      ms >= 1000 ? format("%.2fs", ms / 1000.0) : format("%.1fms", ms)
    end

    def fixed(value) = format("%.1f", value.to_f)

    def signed_fixed(value) = format("%+.1f", value.to_f)

    def signed_integer(value) = format("%+d", value.to_i)

    def percent(value) = format("%.1f%%", value.to_f)

    def signed_percent(value) = format("%+.1f%%", value.to_f)
  end
end
