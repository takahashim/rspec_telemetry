# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe RSpecTelemetry::Recorder do
  around do |example|
    Dir.mktmpdir { |dir|
      @dir = dir
      example.run
    }
  end

  let(:enabled) { true }
  let(:events) { File.readlines(File.join(@dir, "out.ndjson"), chomp: true).map { |l| JSON.parse(l) } }
  let(:recorder) do
    config = RSpecTelemetry::Config.new
    config.enabled = enabled
    config.print_summary = false
    config.output_path = File.join(@dir, "out.ndjson")
    described_class.new(config)
  end

  it "adds common fields to every event" do
    recorder.start
    recorder.record("example.started", file_path: "x")
    recorder.finish

    event = events.first
    expect(event).to(include("type" => "example.started", "file_path" => "x", "pid" => Process.pid))
    expect(event["timestamp"]).to(match(/\AZ?|\d{4}-\d{2}-\d{2}T.*Z\z/))
    expect(event["timestamp"]).to(end_with("Z"))
    expect(event).to(have_key("monotonic_time"))
    expect(event).to(have_key("thread_id"))
  end

  it "uses the current thread-local example id" do
    recorder.start
    recorder.set_current_example("eid-1")
    recorder.record("factory_bot.run_factory", factory: "user")
    recorder.clear_current_example
    recorder.record("factory_bot.run_factory", factory: "order")
    recorder.finish

    expect(events.map { |e| e["example_id"] }).to(eq(["eid-1", nil]))
  end

  context "config is not enabled" do

    let(:enabled) { false }

    it "records nothing when disabled" do
      recorder.start
      expect(recorder.started?).to(be(false))
      recorder.record("example.started")
      recorder.finish
      expect(File.exist?(File.join(@dir, "out.ndjson"))).to(be(false))
    end
  end
end
