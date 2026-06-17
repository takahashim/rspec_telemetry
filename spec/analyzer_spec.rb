# frozen_string_literal: true

require "spec_helper"
require "rspec_telemetry/analyzer"
require "tmpdir"
require "json"

RSpec.describe RSpecTelemetry::Analyzer do
  include NdjsonHelpers

  let(:events) do
    [
      {"type" => "example.started", "example_id" => "a", "file_path" => "spec/a_spec.rb"},
      {
        "type" => "factory_bot.run_factory",
        "example_id" => "a",
        "factory" => "order",
        "strategy" => "create",
        "duration_ms" => 100.0,
        "self_duration_ms" => 30.0
      },
      {
        "type" => "factory_bot.run_factory",
        "example_id" => "a",
        "factory" => "user",
        "strategy" => "create",
        "duration_ms" => 70.0,
        "self_duration_ms" => 70.0,
        "depth" => 1
      },
      {
        "type" => "example.finished",
        "example_id" => "a",
        "file_path" => "spec/a_spec.rb",
        "line_number" => 1,
        "full_description" => "A is slow",
        "status" => "passed",
        "duration_ms" => 250.0
      },
      {
        "type" => "example.finished",
        "example_id" => "b",
        "file_path" => "spec/b_spec.rb",
        "line_number" => 3,
        "full_description" => "B is fast",
        "status" => "passed",
        "duration_ms" => 10.0
      },
      {
        "type" => "suite.finished",
        "example_id" => nil,
        "duration_ms" => 400.0,
        "example_count" => 2,
        "failure_count" => 0,
        "pending_count" => 0
      }
    ]
  end

  it "aggregates examples, factories and files across the run" do
    Dir.mktmpdir do |dir|
      path = write_ndjson(dir, "t.ndjson", events)
      a = described_class.load(path)

      expect(a.example_count).to(eq(2))
      expect(a.total_example_ms).to(eq(260.0))
      # self時間で集計(orderは子70を除く30)
      expect(a.total_factory_self_ms).to(eq(100.0))
      expect(a.slow_examples.first.example_id).to(eq("a"))
      expect(a.slow_files.first.file_path).to(eq("spec/a_spec.rb"))
    end
  end

  it "attaches factory self time to the owning example regardless of event order" do
    Dir.mktmpdir do |dir|
      path = write_ndjson(dir, "t.ndjson", events)
      a = described_class.load(path)

      ex = a.slow_examples.find { |e| e.example_id == "a" }
      expect(ex.fb_count).to(eq(2))
      expect(ex.fb_self_total_ms).to(eq(100.0))
    end
  end

  it "ranks factories by self time" do
    Dir.mktmpdir do |dir|
      path = write_ndjson(dir, "t.ndjson", events)
      a = described_class.load(path)

      top = a.top_factories
      expect(top.map(&:factory)).to(eq(%w[user order]))
      order = top.find { |f| f.factory == "order" }
      expect(order.total_ms).to(eq(100.0))
      expect(order.self_total_ms).to(eq(30.0))
    end
  end

  it "merges multiple files (parallel workers)" do
    Dir.mktmpdir do |dir|
      p1 = write_ndjson(dir, "t.1.ndjson", events)
      p2 = write_ndjson(
        dir,
        "t.2.ndjson",
        [
          {
            "type" => "example.finished",
            "example_id" => "c",
            "file_path" => "spec/c_spec.rb",
            "duration_ms" => 5.0,
            "status" => "passed"
          },
          {
            "type" => "suite.finished",
            "duration_ms" => 50.0,
            "example_count" => 1,
            "failure_count" => 0,
            "pending_count" => 0
          }
        ]
      )
      a = described_class.load([p1, p2])
      expect(a.example_count).to(eq(3))
    end
  end

  it "tolerates malformed lines" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "bad.ndjson")
      File.write(path, "not json\n#{JSON.generate(events.last)}\n")
      expect { described_class.load(path) }.not_to(raise_error)
    end
  end

  it "extracts events for a single example for drill-down" do
    Dir.mktmpdir do |dir|
      path = write_ndjson(dir, "t.ndjson", events)
      found = described_class.events_for_example(path, "a")
      expect(found.map { |e| e["type"] }).to(include("factory_bot.run_factory", "example.finished"))
      expect(found).to(all(include("example_id" => "a")))
    end
  end
end
