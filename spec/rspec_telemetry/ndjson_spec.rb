# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  # The trust boundary: raw NDJSON lines (untrusted file bytes) -> clean Hashes.
  RSpec.describe Ndjson do
    it "parses a JSON object line into a Hash" do
      expect(Ndjson.parse("{\"type\":\"example.started\",\"example_id\":\"a\"}"))
        .to eq("type" => "example.started", "example_id" => "a")
    end

    it "returns nil for a blank line" do
      expect(Ndjson.parse("")).to be_nil
      expect(Ndjson.parse("   \n")).to be_nil
    end

    it "returns nil for an invalid / half-written line" do
      expect(Ndjson.parse("{\"type\":\"example.start")).to be_nil
    end

    it "returns nil for a non-object scalar or array" do
      expect(Ndjson.parse("42")).to be_nil
      expect(Ndjson.parse("[1,2,3]")).to be_nil
    end

    it "scrubs invalid UTF-8 before parsing so values stay valid" do
      # stray byte inside a JSON string
      line = "{\"factory\":\"user\xE3\"}"
      result = Ndjson.parse(line)
      expect(result).to eq("factory" => "user?")
      expect(result["factory"].valid_encoding?).to be(true)
    end

    it "scrub turns invalid bytes into valid UTF-8" do
      expect(Ndjson.scrub("ok")).to eq("ok")
      scrubbed = Ndjson.scrub("a\xE3b")
      expect(scrubbed.valid_encoding?).to be(true)
    end
  end
end
