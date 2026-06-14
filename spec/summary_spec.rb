# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe RSpecTelemetry::Summary do
  let(:config) { RSpecTelemetry::Config.new }
  subject(:summary) { described_class.new(config) }

  def factory_event(factory:, duration:, self_ms: nil, example_id: nil, strategy: "create")
    {
      type: "factory_bot.run_factory",
      factory: factory,
      strategy: strategy,
      duration_ms: duration,
      self_duration_ms: self_ms || duration,
      example_id: example_id
    }
  end

  it "aggregates factory stats by factory:strategy" do
    summary.add(factory_event(factory: "user", duration: 10.0))
    summary.add(factory_event(factory: "user", duration: 30.0))
    summary.add(factory_event(factory: "order", duration: 5.0))

    user = summary.factories.find { |f| f.key == "user:create" }
    expect(user.count).to(eq(2))
    expect(user.total_ms).to(eq(40.0))
    expect(user.avg_ms).to(eq(20.0))
    expect(user.max_ms).to(eq(30.0))
  end

  it "ranks factories by self time, not total time" do
    # order: total大きいが子factoryを含むためself小さい
    summary.add(factory_event(factory: "order", duration: 100.0, self_ms: 10.0))
    summary.add(factory_event(factory: "user", duration: 40.0, self_ms: 40.0))

    expect(summary.top_factories.map(&:factory)).to(eq(%w[user order]))
  end

  it "accumulates per-example factory totals using self time" do
    eid = "./spec/x_spec.rb[1:1]"
    summary.add(factory_event(factory: "order", duration: 100.0, self_ms: 60.0, example_id: eid))
    summary.add(factory_event(factory: "user", duration: 40.0, self_ms: 40.0, example_id: eid))
    summary.add(
      type: "example.finished",
      example_id: eid,
      file_path: "./spec/x_spec.rb",
      line_number: 1,
      duration_ms: 250.0
    )

    ex = summary.examples.first
    expect(ex.duration_ms).to(eq(250.0))
    expect(ex.factory_bot_total_ms).to(eq(100.0))
    expect(ex.factory_bot_count).to(eq(2))
  end

  it "filters slow examples by threshold" do
    config.slow_example_threshold_ms = 100.0
    summary.add(type: "example.finished", example_id: "a", duration_ms: 50.0)
    summary.add(type: "example.finished", example_id: "b", duration_ms: 200.0)

    expect(summary.slow_examples.map(&:example_id)).to(eq(["b"]))
  end

  it "prints a summary to the configured io when print_summary is enabled" do
    io = StringIO.new
    config.summary_io = io
    config.print_summary = true
    summary.add(factory_event(factory: "user", duration: 10.0, self_ms: 10.0))

    RSpecTelemetry::SummaryPrinter.print(summary, config, io)
    expect(io.string).to(include("FactoryBot telemetry summary"))
    expect(io.string).to(include("user:create"))
  end

  it "prints nothing by default (print_summary is off)" do
    io = StringIO.new
    config.summary_io = io
    summary.add(factory_event(factory: "user", duration: 10.0, self_ms: 10.0))

    RSpecTelemetry::SummaryPrinter.print(summary, config, io)
    expect(io.string).to(be_empty)
  end
end
