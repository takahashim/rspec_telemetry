# frozen_string_literal: true

require "rspec/core"
require "rspec/core/formatters/base_formatter"

module RSpecTelemetry
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    RSpec::Core::Formatters.register(
      self,
      :start,
      :example_started,
      :example_finished,
      :dump_summary,
      :close
    )

    def start(_notification)
      RSpecTelemetry.safely("formatter#start") { RSpecTelemetry.start! }
    end

    def example_started(notification)
      RSpecTelemetry.safely("formatter#example_started") do
        example = notification.example
        # Runs before before(:each), so FactoryBot calls inside hooks get this example_id.
        recorder.set_current_example(example.id)
        next unless config.capture_examples

        recorder.record(
          "example.started",
          file_path: example.file_path,
          line_number: example.metadata[:line_number],
          full_description: example.full_description
        )
      end
    end

    def example_finished(notification)
      RSpecTelemetry.safely("formatter#example_finished") do
        example = notification.example
        record_example_finished(example) if config.capture_examples
        recorder.flush
      ensure
        # Avoid attributing after(:suite) or later work to the last example.
        recorder.clear_current_example
      end
    end

    def dump_summary(notification)
      RSpecTelemetry.safely("formatter#dump_summary") do
        recorder.record(
          "suite.finished",
          example_id: nil,
          duration_ms: (notification.duration * 1000.0).round(3),
          example_count: notification.example_count,
          failure_count: notification.failure_count,
          pending_count: notification.pending_count
        )
      end
    end

    def close(_notification)
      RSpecTelemetry.safely("formatter#close") { RSpecTelemetry.finish! }
    end

    private

    def record_example_finished(example)
      result = example.execution_result
      exception = result.exception

      recorder.record(
        "example.finished",
        file_path: example.file_path,
        line_number: example.metadata[:line_number],
        full_description: example.full_description,
        status: result.status.to_s,
        duration_ms: (result.run_time.to_f * 1000.0).round(3),
        exception_class: exception&.class&.name,
        exception_message: exception&.message
      )
    end

    def recorder
      RSpecTelemetry.recorder
    end

    def config
      RSpecTelemetry.config
    end
  end
end
