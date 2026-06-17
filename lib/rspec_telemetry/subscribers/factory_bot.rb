# frozen_string_literal: true

# isolated_execution_state only exists on Rails 7+; ActiveSupport::Notifications
# works without it, so make it optional to support Rails 6.x (and earlier).
begin
  require "active_support/isolated_execution_state"
rescue LoadError
  nil
end
require "active_support/notifications"

module RSpecTelemetry
  module Subscribers
    class FactoryBot
      STACK_KEY = :rspec_telemetry_fb_stack

      def initialize(recorder)
        @recorder = recorder
        @subscription = nil
      end

      def subscribe
        @subscription = ActiveSupport::Notifications.subscribe("factory_bot.run_factory", self)
      end

      def unsubscribe
        ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
        @subscription = nil
      end

      def start(_name, _id, payload)
        RSpecTelemetry.safely("factory_bot#start") do
          stack.push(
            name: payload[:name].to_s,
            monotonic: Process.clock_gettime(Process::CLOCK_MONOTONIC),
            child_ms: 0.0
          )
        end
      end

      def finish(_name, _id, payload)
        RSpecTelemetry.safely("factory_bot#finish") do
          frame = stack.pop
          next unless frame
          next unless @recorder.config.enabled && @recorder.config.capture_factory_bot

          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          total = ((now - frame[:monotonic]) * 1000.0).round(3)
          self_ms = (total - frame[:child_ms]).round(3)

          parent = stack.last
          parent[:child_ms] += total if parent

          @recorder.record(
            "factory_bot.run_factory",
            factory: payload[:name].to_s,
            strategy: payload[:strategy].to_s,
            traits: Array(payload[:traits]).map(&:to_s),
            overrides: override_names(payload[:overrides]),
            duration_ms: total,
            self_duration_ms: self_ms,
            depth: stack.size,
            parent_factory: parent && parent[:name],
            factory_class: build_class_name(payload[:factory])
          )
        end
      end

      private

      def override_names(overrides)
        return [] unless overrides.is_a?(Hash)

        overrides.keys.map(&:to_s)
      end

      def build_class_name(factory)
        factory.build_class.to_s
      rescue StandardError
        nil
      end

      def stack
        Thread.current[STACK_KEY] ||= []
      end
    end
  end
end
