# frozen_string_literal: true

require "json"

module RSpecTelemetry
  module Ndjson
    # Trace files are untrusted and may contain a truncated final line after a crash.
    def self.parse(line)
      text = scrub(line).strip
      return nil if text.empty?

      value = JSON.parse(text)
      value.is_a?(Hash) ? value : nil
    rescue JSON::ParserError
      nil
    end

    # Keep downstream rendering on valid UTF-8 even when the trace has bad bytes.
    def self.scrub(line)
      string = line.to_s
      string.valid_encoding? ? string : string.scrub("?")
    end
  end
end
