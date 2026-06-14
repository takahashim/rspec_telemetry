# frozen_string_literal: true

module RSpecTelemetry
  class Config
    attr_accessor(
      :enabled,
      :output_path,
      :capture_examples,
      :capture_factory_bot,
      :print_summary,
      :flush_each,
      :slow_factory_threshold_ms,
      :slow_example_threshold_ms,
      :summary_io,
      :summary_limit
    )

    def initialize
      @enabled = true
      @output_path = self.class.default_output_path
      @capture_examples = true
      @capture_factory_bot = true
      @print_summary = false
      @flush_each = false
      @slow_factory_threshold_ms = nil
      @slow_example_threshold_ms = nil
      @summary_io = $stderr
      @summary_limit = 20
    end

    def self.default_output_path
      suffix = ENV["TEST_ENV_NUMBER"]
      if suffix && !suffix.empty?
        "tmp/rspec_telemetry.#{suffix}.ndjson"
      else
        "tmp/rspec_telemetry.ndjson"
      end
    end
  end
end
