# frozen_string_literal: true

require "spec_helper"
require "rspec_telemetry/cli"
require "tmpdir"
require "json"
require "stringio"

RSpec.describe RSpecTelemetry::CLI do
  def run_cli(argv)
    out = StringIO.new
    err = StringIO.new
    code = described_class.new(argv, out: out, err: err).run
    [code, out.string, err.string]
  end

  let(:events) do
    [
      {
        "type" => "factory_bot.run_factory",
        "example_id" => "a",
        "factory" => "user",
        "strategy" => "create",
        "traits" => ["admin"],
        "duration_ms" => 80.0,
        "self_duration_ms" => 80.0,
        "depth" => 0
      },
      {
        "type" => "example.finished",
        "example_id" => "a",
        "file_path" => "spec/a_spec.rb",
        "line_number" => 1,
        "full_description" => "A example",
        "status" => "passed",
        "duration_ms" => 120.0
      },
      {
        "type" => "suite.finished",
        "duration_ms" => 200.0,
        "example_count" => 1,
        "failure_count" => 0,
        "pending_count" => 0
      }
    ]
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @path = File.join(dir, "t.ndjson")
      File.write(@path, events.map { |e| JSON.generate(e) }.join("\n") + "\n")
      example.run
    end
  end

  it "prints a report with the main sections" do
    code, out, = run_cli([@path])
    expect(code).to(eq(0))
    expect(out).to(include("Overview"))
    expect(out).to(include("Slowest examples"))
    expect(out).to(include("Slowest factories"))
    expect(out).to(include("user:create"))
    expect(out).to(include("A example"))
  end

  it "drills down into a single example" do
    code, out, = run_cli([@path, "--example", "a"])
    expect(code).to(eq(0))
    expect(out).to(include("Example: a"))
    expect(out).to(include("user:create"))
    expect(out).to(include("[admin]"))
  end

  it "errors clearly when no files are found" do
    code, _out, err = run_cli(["/nonexistent/does_not_exist.ndjson"])
    expect(code).to(eq(1))
    expect(err).to(include("File not found").or(include("No telemetry")))
  end

  it "respects --top" do
    code, out, = run_cli([@path, "--top", "1"])
    expect(code).to(eq(0))
    expect(out).to(include("Overview"))
  end
end
