# frozen_string_literal: true

# gem自身のテスト実行に対してformatterを自動登録しないようにする。
ENV["RSPEC_TELEMETRY_NO_AUTOLOAD"] = "1"

# collector (formatter / subscriber / writer / analyzer)
require "rspec_telemetry"

# viewer (TUI over the NDJSON)
require "rspec_telemetry/trace/viewer"
require "json"

module RSpecTelemetry
  module Trace
    module Viewer
      # Builders for rspec_telemetry NDJSON lines, so viewer specs read as small
      # event scripts instead of hand-written JSON. `mono` is the monotonic_time
      # used to synthesize wall_ms; pass it when a spec cares about timing.
      module Fixtures
        module_function

        def jline(hash) = JSON.generate(hash.compact)

        def started(id:, file: "spec/x_spec.rb", line: 1, desc: nil, mono: nil)
          jline(
            type: "example.started",
            monotonic_time: mono,
            example_id: id,
            file_path: file,
            line_number: line,
            full_description: desc || id
          )
        end

        def factory(
          name:,
          ex:,
          strategy: "create",
          dur: 1.0,
          self_ms: nil,
          depth: 0,
          parent: nil,
          traits: [],
          overrides: [],
          klass: nil,
          mono: nil
        )
          jline(
            type: "factory_bot.run_factory",
            monotonic_time: mono,
            example_id: ex,
            factory: name,
            strategy: strategy,
            traits: traits,
            overrides: overrides,
            duration_ms: dur,
            self_duration_ms: self_ms || dur,
            depth: depth,
            parent_factory: parent,
            factory_class: klass
          )
        end

        def finished(
          id:,
          status: "passed",
          dur: 1.0,
          exc: nil,
          file: "spec/x_spec.rb",
          line: 1,
          desc: nil,
          mono: nil
        )
          jline(
            type: "example.finished",
            monotonic_time: mono,
            example_id: id,
            file_path: file,
            line_number: line,
            full_description: desc || id,
            status: status,
            duration_ms: dur,
            exception_class: exc && exc[0],
            exception_message: exc && exc[1]
          )
        end

        def suite(examples: 1, failures: 0, pending: 0, dur: 1.0, mono: nil)
          jline(
            type: "suite.finished",
            monotonic_time: mono,
            example_id: nil,
            duration_ms: dur,
            example_count: examples,
            failure_count: failures,
            pending_count: pending
          )
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random

  config.after { RSpecTelemetry.reset! }
end
