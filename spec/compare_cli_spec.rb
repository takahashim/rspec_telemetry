# frozen_string_literal: true

require "json"
require "rspec_telemetry/compare_cli"
require "tmpdir"
require "stringio"

RSpec.describe RSpecTelemetry::CompareCLI do
  around do |example|
    Dir.mktmpdir do |dir|
      @before_path = File.join(dir, "before.ndjson")
      @after_path = File.join(dir, "after.ndjson")
      File.write(
        @before_path,
        JSON.generate(
          "type" => "factory_bot.run_factory",
          "factory" => "ticket_book",
          "strategy" => "create",
          "depth" => 0,
          "duration_ms" => 100
        ) + "\n"
      )
      File.write(
        @after_path,
        JSON.generate(
          "type" => "factory_bot.run_factory",
          "factory" => "ticket_book",
          "strategy" => "create",
          "depth" => 0,
          "duration_ms" => 25
        ) + "\n"
      )
      example.run
    end
  end

  it "prints count and duration differences" do
    out = StringIO.new
    err = StringIO.new

    code = described_class.new([@before_path, @after_path], out: out, err: err).run

    expect(code).to eq(0)
    expect(err.string).to be_empty
    expect(out.string).to include("Factory:Strategy")
    expect(out.string).to include("ticket_book:create")
    expect(out.string).to include("-75.0")
    expect(out.string).to include("-75.0%")
  end

  it "appends a TOTAL row summing every factory" do
    out = StringIO.new
    err = StringIO.new

    code = described_class.new([@before_path, @after_path], out: out, err: err).run

    expect(code).to eq(0)
    total = out.string.lines.find { |line| line.start_with?("TOTAL") }
    expect(total).not_to be_nil
    # before 100 -> after 25 across the single factory
    expect(total).to include("100.0")
    expect(total).to include("25.0")
    expect(total).to include("-75.0%")
  end

  it "requires exactly two paths" do
    out = StringIO.new
    err = StringIO.new

    code = described_class.new([@before_path], out: out, err: err).run

    expect(code).to eq(1)
    expect(err.string).to include("BEFORE AFTER")
  end

  it "combines strategies per factory with --by-factory" do
    out = StringIO.new
    err = StringIO.new

    code = described_class.new(
      [@before_path, @after_path, "--by-factory"],
      out: out,
      err: err
    ).run

    expect(code).to eq(0)
    expect(out.string).to include("Factory ")
    expect(out.string).to include("ticket_book")
    expect(out.string).not_to include("ticket_book:create")
  end

  it "labels all-depth timing as self time" do
    out = StringIO.new
    err = StringIO.new

    code = described_class.new(
      [@before_path, @after_path, "--all-depths"],
      out: out,
      err: err
    ).run

    expect(code).to eq(0)
    expect(out.string).to include("Before Self(ms)")
  end
end
