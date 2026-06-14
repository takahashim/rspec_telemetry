# frozen_string_literal: true

require "json"
require "fileutils"

module RSpecTelemetry
  class Writer
    def initialize(output_path, flush_each: false)
      @output_path = output_path
      @flush_each = flush_each
      @mutex = Mutex.new
      @io = nil
    end

    def open
      FileUtils.mkdir_p(File.dirname(@output_path))
      # Each run gets a fresh stream; appending would create misleading time gaps.
      @io = File.open(@output_path, "w")
    rescue => e
      warn_failure("open", e)
      @io = nil
    end

    def write(event)
      return unless @io

      @mutex.synchronize do
        @io.puts(JSON.generate(event))
        @io.flush if @flush_each
      end

    rescue => e
      warn_failure("write", e)
    end

    def flush
      @mutex.synchronize { @io&.flush }
    rescue => e
      warn_failure("flush", e)
    end

    def close
      @mutex.synchronize do
        @io&.flush
        @io&.close
        @io = nil
      end

    rescue => e
      warn_failure("close", e)
    end

    private

    def warn_failure(action, error)
      warn("[rspec-telemetry] failed to #{action} event: #{error.class}: #{error.message}")
    end
  end
end
