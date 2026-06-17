# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"

RSpec.describe RSpecTelemetry::Writer do
  around do |example|
    Dir.mktmpdir { |dir|
      @dir = dir
      example.run
    }
  end

  let(:path) { File.join(@dir, "nested", "out.ndjson") }

  it "writes one JSON object per line and creates the directory" do
    writer = described_class.new(path)
    writer.open
    writer.write(type: "a", n: 1)
    writer.write(type: "b", n: 2)
    writer.close

    lines = File.readlines(path, chomp: true)
    expect(lines.size).to(eq(2))
    expect(JSON.parse(lines[0])).to(eq("type" => "a", "n" => 1))
    expect(JSON.parse(lines[1])).to(eq("type" => "b", "n" => 2))
  end

  it "truncates on open so each run is a fresh file (no cross-run accumulation)" do
    first = described_class.new(path)
    first.open
    first.write(type: "run1", n: 1)
    first.close

    second = described_class.new(path)
    second.open
    second.write(type: "run2", n: 1)
    second.close

    lines = File.readlines(path, chomp: true)
    expect(lines.size).to(eq(1))
    expect(JSON.parse(lines[0])).to(eq("type" => "run2", "n" => 1))
  end

  it "does not raise when writing before open" do
    writer = described_class.new(path)
    expect { writer.write(type: "x") }.not_to(raise_error)
  end

  it "swallows write errors and warns instead of raising" do
    writer = described_class.new(path)
    writer.open
    bad = Object.new.tap { |o| def o.to_json(*) = raise "boom" }
    expect { writer.write(type: "x", bad: bad) }.to(output(/failed to write/).to_stderr)
    writer.close
  end
end
