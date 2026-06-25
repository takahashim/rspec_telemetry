# frozen_string_literal: true

require "time"

require_relative "summary"

module RSpecTelemetry
  class Recorder
    # FactoryBot notifications read this to attach themselves to the active example.
    EXAMPLE_ID = :rspec_telemetry_example_id

    attr_reader :config, :summary

    def initialize(config, writer: nil, summary: nil)
      @config = config
      @writer = writer || Writer.new(config.output_path, flush_each: config.flush_each)
      @summary = summary || Summary.new(config)
      @started = false
    end

    def start
      return if @started || !@config.enabled

      @writer.open
      @started = true
    end

    def started?
      @started
    end

    def record(type, fields = {})
      return unless @config.enabled && @started

      event = common_fields(type).merge(fields)
      @writer.write(event)
      @summary.add(event)
      event
    end

    def flush
      @writer.flush
    end

    def finish
      return unless @started

      @writer.close
      @started = false
    end

    def common_fields(type)
      {
        type: type,
        timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6NZ"),
        monotonic_time: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        pid: Process.pid,
        thread_id: self.class.thread_id,
        example_id: Thread.current[EXAMPLE_ID]
      }
    end

    def set_current_example(id)
      Thread.current[EXAMPLE_ID] = id
    end

    def clear_current_example
      Thread.current[EXAMPLE_ID] = nil
    end

    def self.thread_id
      t = Thread.current
      t.respond_to?(:native_thread_id) && t.native_thread_id ? t.native_thread_id : t.object_id
    end
  end
end
