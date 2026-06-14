# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpecTelemetry::FactoryAggregation::Accumulator do
  subject(:acc) { described_class.new }

  it "rolls up count, total, self and max per factory:strategy" do
    acc.add(factory: "user", strategy: "create", duration_ms: 10.0, self_duration_ms: 10.0)
    acc.add(factory: "user", strategy: "create", duration_ms: 30.0, self_duration_ms: 20.0)

    stat = acc.stats.find { |s| s.key == "user:create" }
    expect(stat.count).to(eq(2))
    expect(stat.total_ms).to(eq(40.0))
    expect(stat.self_total_ms).to(eq(30.0))
    expect(stat.max_ms).to(eq(30.0))
    expect(stat.avg_ms).to(eq(20.0))
  end

  it "defaults self_duration_ms to duration_ms when omitted" do
    acc.add(factory: "user", strategy: "build", duration_ms: 5.0)
    expect(acc.stats.first.self_total_ms).to(eq(5.0))
  end

  it "ranks by self time, slowest first, and honors a limit" do
    acc.add(factory: "order", strategy: "create", duration_ms: 100.0, self_duration_ms: 10.0)
    acc.add(factory: "user", strategy: "create", duration_ms: 40.0, self_duration_ms: 40.0)

    expect(acc.top.map(&:factory)).to(eq(%w[user order]))
    expect(acc.top(1).map(&:factory)).to(eq(["user"]))
  end

  it "coerces nil/missing durations to zero rather than raising" do
    expect { acc.add(factory: "user", strategy: "create", duration_ms: nil) }.not_to(raise_error)
    expect(acc.stats.first.total_ms).to(eq(0.0))
  end
end
