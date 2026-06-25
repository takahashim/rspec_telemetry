# frozen_string_literal: true

require "json"
require "rspec_telemetry/factory_comparison"
require "tmpdir"

RSpec.describe RSpecTelemetry::FactoryComparison do
  def write_events(path, events)
    File.write(path, events.map { |event| JSON.generate(event) }.join("\n") + "\n")
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @before_path = File.join(dir, "before.ndjson")
      @after_path = File.join(dir, "after.ndjson")
      example.run
    end
  end

  it "compares root factory counts and durations" do
    write_events(
      @before_path,
      [
        {"type" => "factory_bot.run_factory", "factory" => "user", "depth" => 0, "duration_ms" => 20},
        {"type" => "factory_bot.run_factory", "factory" => "user", "depth" => 0, "duration_ms" => 30},
        {"type" => "factory_bot.run_factory", "factory" => "profile", "depth" => 1, "duration_ms" => 5}
      ]
    )
    write_events(
      @after_path,
      [
        {"type" => "factory_bot.run_factory", "factory" => "user", "depth" => 0, "duration_ms" => 15},
        {"type" => "factory_bot.run_factory", "factory" => "order", "depth" => 0, "duration_ms" => 8}
      ]
    )

    rows = described_class.new(@before_path, @after_path).rows.to_h { |row| [row.factory, row] }

    expect(rows.keys).to contain_exactly("order", "user")
    expect(rows["user"].before_count).to eq(2)
    expect(rows["user"].after_count).to eq(1)
    expect(rows["user"].duration_diff_ms).to eq(-35.0)
    expect(rows["order"].count_change_percent).to be_nil
  end

  it "can include nested factory events" do
    before_events = [
      {
        "type" => "factory_bot.run_factory",
        "factory" => "profile",
        "depth" => 1,
        "duration_ms" => 20,
        "self_duration_ms" => 5
      }
    ]
    after_events = [
      {
        "type" => "factory_bot.run_factory",
        "factory" => "profile",
        "depth" => 1,
        "duration_ms" => 10,
        "self_duration_ms" => 3
      }
    ]
    write_events(@before_path, before_events)
    write_events(@after_path, after_events)

    rows = described_class.new(@before_path, @after_path, all_depths: true).rows

    expect(rows.map(&:factory)).to eq(["profile"])
    expect(rows.first.before_duration_ms).to eq(5.0)
    expect(rows.first.after_duration_ms).to eq(3.0)
  end
end
