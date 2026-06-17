# frozen_string_literal: true

require "json"

# Writes NDJSON fixture files for Analyzer specs (one JSON object per line).
module NdjsonHelpers
  def write_ndjson(dir, name, events)
    path = File.join(dir, name)
    File.write(path, events.map { |e| JSON.generate(e) }.join("\n") + "\n")
    path
  end
end
