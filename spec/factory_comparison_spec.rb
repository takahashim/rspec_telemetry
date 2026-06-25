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

  it "compares root factory counts and durations keyed by factory:strategy" do
    write_events(
      @before_path,
      [
        {"type" => "factory_bot.run_factory", "factory" => "user", "strategy" => "create", "depth" => 0, "duration_ms" => 20},
        {"type" => "factory_bot.run_factory", "factory" => "user", "strategy" => "create", "depth" => 0, "duration_ms" => 30},
        {"type" => "factory_bot.run_factory", "factory" => "profile", "strategy" => "create", "depth" => 1, "duration_ms" => 5}
      ]
    )
    write_events(
      @after_path,
      [
        {"type" => "factory_bot.run_factory", "factory" => "user", "strategy" => "create", "depth" => 0, "duration_ms" => 15},
        {"type" => "factory_bot.run_factory", "factory" => "order", "strategy" => "create", "depth" => 0, "duration_ms" => 8}
      ]
    )

    rows = described_class.new(@before_path, @after_path).rows.to_h { |row| [row.label, row] }

    expect(rows.keys).to contain_exactly("order:create", "user:create")
    expect(rows["user:create"].before_count).to eq(2)
    expect(rows["user:create"].after_count).to eq(1)
    expect(rows["user:create"].duration_diff_ms).to eq(-35.0)
    expect(rows["order:create"].count_change_percent).to be_nil
  end

  it "keeps create and build as separate rows" do
    write_events(
      @before_path,
      [
        {"type" => "factory_bot.run_factory", "factory" => "user", "strategy" => "create", "depth" => 0, "duration_ms" => 20},
        {"type" => "factory_bot.run_factory", "factory" => "user", "strategy" => "build", "depth" => 0, "duration_ms" => 5}
      ]
    )
    write_events(@after_path, [])

    rows = described_class.new(@before_path, @after_path).rows.to_h { |row| [row.label, row] }

    expect(rows.keys).to contain_exactly("user:build", "user:create")
    expect(rows["user:create"].before_count).to eq(1)
    expect(rows["user:build"].before_count).to eq(1)
  end

  it "combines strategies per factory with by_factory" do
    write_events(
      @before_path,
      [
        {"type" => "factory_bot.run_factory", "factory" => "user", "strategy" => "create", "depth" => 0, "duration_ms" => 20},
        {"type" => "factory_bot.run_factory", "factory" => "user", "strategy" => "build", "depth" => 0, "duration_ms" => 5}
      ]
    )
    write_events(@after_path, [])

    rows = described_class.new(@before_path, @after_path, by_factory: true).rows.to_h { |row| [row.label, row] }

    expect(rows.keys).to contain_exactly("user")
    expect(rows["user"].before_count).to eq(2)
    expect(rows["user"].before_duration_ms).to eq(25.0)
  end

  it "can include nested factory events and compares self time" do
    before_events = [
      {
        "type" => "factory_bot.run_factory",
        "factory" => "profile",
        "strategy" => "create",
        "depth" => 1,
        "duration_ms" => 20,
        "self_duration_ms" => 5
      }
    ]
    after_events = [
      {
        "type" => "factory_bot.run_factory",
        "factory" => "profile",
        "strategy" => "create",
        "depth" => 1,
        "duration_ms" => 10,
        "self_duration_ms" => 3
      }
    ]
    write_events(@before_path, before_events)
    write_events(@after_path, after_events)

    rows = described_class.new(@before_path, @after_path, all_depths: true).rows

    expect(rows.map(&:label)).to eq(["profile:create"])
    expect(rows.first.before_duration_ms).to eq(5.0)
    expect(rows.first.after_duration_ms).to eq(3.0)
  end
end
