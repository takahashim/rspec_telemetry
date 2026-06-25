# frozen_string_literal: true

require_relative "rspec_telemetry/version"
require_relative "rspec_telemetry/config"
require_relative "rspec_telemetry/writer"
require_relative "rspec_telemetry/summary"
require_relative "rspec_telemetry/recorder"

module RSpecTelemetry
  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config if block_given?
      config
    end

    def recorder
      @recorder ||= Recorder.new(config)
    end

    def start!
      return unless config.enabled

      recorder.start
      return unless recorder.started?

      subscribe!
      recorder
    end

    def finish!
      active = @recorder
      if active&.started?
        # Printing the end-of-run summary is a reporting concern owned by the
        # lifecycle, not by the Recorder (which only records events).
        SummaryPrinter.print(active.summary, config)
      end
      active&.finish
      unsubscribe!
    end

    def reset!
      unsubscribe!
      @config = nil
      @recorder = nil
      @warned = nil
    end

    def safely(context)
      yield
    # Telemetry must never break the user's RSpec run, even on non-StandardError failures.
    rescue Exception => e # rubocop:disable Lint/RescueException
      warn_once(context, e)
      nil
    end

    private

    def warn_once(context, error)
      @warned ||= {}
      return if @warned[context]

      @warned[context] = true
      warn(
        "[rspec-telemetry] #{context} で例外を無視しました(以後同種は抑制): " \
          "#{error.class}: #{error.message}"
      )
    end

    def subscribe!
      return unless config.capture_factory_bot
      return if @factory_bot_subscriber

      subscriber = build_factory_bot_subscriber
      return unless subscriber

      @factory_bot_subscriber = subscriber
      @factory_bot_subscriber.subscribe
    end

    # activesupport is an optional dependency: it is only needed for FactoryBot
    # tracking, which relies on ActiveSupport::Notifications. FactoryBot itself
    # pulls in activesupport, so when it is absent there are no factory events to
    # capture and we silently skip the subscription.
    def build_factory_bot_subscriber
      require_relative "rspec_telemetry/subscribers/factory_bot"
      Subscribers::FactoryBot.new(recorder)
    rescue LoadError
      nil
    end

    def unsubscribe!
      @factory_bot_subscriber&.unsubscribe
      @factory_bot_subscriber = nil
    end
  end
end

if defined?(RSpec) && RSpec.respond_to?(:configure) && !ENV.key?("RSPEC_TELEMETRY_NO_AUTOLOAD")
  require_relative "rspec_telemetry/formatter"

  RSpec.configure do |config|
    config.add_formatter(RSpecTelemetry::Formatter)
  end
end
