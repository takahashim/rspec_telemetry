# frozen_string_literal: true

require "optparse"

require_relative "analyzer"
require_relative "console_report"

module RSpecTelemetry
  class CLI
    DEFAULT_GLOB = "tmp/rspec_telemetry*.ndjson"

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv
      @out = out
      @err = err
      @options = {top: 15, example: nil}
    end

    def run
      paths = parse!
      if paths.empty?
        @err.puts("No telemetry files found (looked for #{DEFAULT_GLOB}).")
        @err.puts("Run `bundle exec rspec` first, or pass file paths explicitly.")
        return 1
      end

      @options[:example] ? drill_down(paths, @options[:example]) : report(paths)
      0
    rescue Errno::ENOENT => e
      @err.puts("File not found: #{e.message}")
      1
    end

    private

    def parse!
      parser = OptionParser.new do |o|
        o.banner = "Usage: rspec-telemetry [options] [files...]"
        o.on("-n", "--top N", Integer, "Show top N rows per section (default: 15)") { |v| @options[:top] = v }
        o.on("-e", "--example ID", "Drill down into a single example by id") { |v| @options[:example] = v }
        o.on("-h", "--help", "Show this help") do
          @out.puts(o)
          exit(0)
        end

        o.on("-v", "--version", "Show version") do
          @out.puts(RSpecTelemetry::VERSION)
          exit(0)
        end
      end

      files = parser.parse(@argv)
      files.empty? ? Dir.glob(DEFAULT_GLOB).sort : files
    end

    def report(paths)
      analyzer = Analyzer.load(paths)
      @out.puts(ConsoleReport.new(analyzer, files_count: paths.size, top: @options[:top]).render)
    end

    def drill_down(paths, example_id)
      events = Analyzer.events_for_example(paths, example_id)
      if events.empty?
        @err.puts("No events found for example: #{example_id}")
        return
      end

      @out.puts(ConsoleReport.drill_down(events, example_id))
    end
  end
end
