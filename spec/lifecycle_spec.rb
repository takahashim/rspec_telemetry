# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "stringio"

# finish! owns end-of-run reporting: it prints the summary from the recorder it
# manages, while the Recorder itself only records events.
RSpec.describe "RSpecTelemetry.finish!" do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  ensure
    RSpecTelemetry.reset!
  end

  def configure(io)
    RSpecTelemetry.configure do |config|
      config.output_path = File.join(@dir, "out.ndjson")
      config.print_summary = true
      config.summary_io = io
    end
  end

  it "prints the recorder's summary when print_summary is enabled" do
    io = StringIO.new
    configure(io)

    RSpecTelemetry.start!
    RSpecTelemetry.recorder.set_current_example("./spec/x_spec.rb[1:1]")
    RSpecTelemetry.recorder.record("factory_bot.run_factory", factory: "user", strategy: "create", duration_ms: 12.0)
    RSpecTelemetry.recorder.record("example.finished", duration_ms: 30.0)
    RSpecTelemetry.finish!

    expect(io.string).to include("FactoryBot telemetry summary")
    expect(io.string).to include("user:create")
  end

  it "prints nothing when print_summary is disabled" do
    io = StringIO.new
    configure(io)
    RSpecTelemetry.config.print_summary = false

    RSpecTelemetry.start!
    RSpecTelemetry.recorder.record("factory_bot.run_factory", factory: "user", strategy: "create", duration_ms: 12.0)
    RSpecTelemetry.finish!

    expect(io.string).to be_empty
  end
end
