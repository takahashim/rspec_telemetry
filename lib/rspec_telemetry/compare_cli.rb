# frozen_string_literal: true

require "optparse"

require_relative "factory_comparison"
require_relative "formatting"

module RSpecTelemetry
  class CompareCLI
    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv
      @out = out
      @err = err
      @options = {all_depths: false, sort: "duration"}
    end

    def run
      paths = parse!
      unless paths.length == 2
        @err.puts("Specify exactly two telemetry files: BEFORE AFTER")
        return 1
      end

      comparison = FactoryComparison.new(paths[0], paths[1], all_depths: @options[:all_depths])
      rows = sort_rows(comparison.rows)
      @out.puts(render(rows, duration_label: comparison.duration_label))
      0
    rescue Errno::ENOENT => e
      @err.puts("File not found: #{e.message}")
      1
    rescue OptionParser::ParseError => e
      @err.puts(e.message)
      1
    end

    private

    def parse!
      parser = OptionParser.new do |options|
        options.banner = "Usage: rspec-telemetry-compare [options] BEFORE AFTER"
        options.on("--all-depths", "Include nested FactoryBot events") do
          @options[:all_depths] = true
        end
        options.on(
          "--sort KEY",
          %w[duration count factory],
          "Sort by duration, count, or factory (default: duration)"
        ) do |value|
          @options[:sort] = value
        end
        options.on("-h", "--help", "Show this help") do
          @out.puts(options)
          exit(0)
        end
      end

      parser.parse(@argv)
    end

    def sort_rows(rows)
      case @options[:sort]
      when "count"
        rows.sort_by { |row| [-row.count_diff.abs, row.label] }
      when "factory"
        rows.sort_by(&:label)
      else
        rows.sort_by { |row| [-row.duration_diff_ms.abs, row.label] }
      end
    end

    def render(rows, duration_label:)
      headings = [
        "Factory:Strategy",
        "Before",
        "After",
        "Diff",
        "Change",
        "Before #{duration_label}",
        "After #{duration_label}",
        "Diff(ms)",
        "Change"
      ]
      body = rows.map do |row|
        [
          row.label,
          row.before_count.to_s,
          row.after_count.to_s,
          Formatting.signed_integer(row.count_diff),
          percent(row.count_change_percent),
          Formatting.fixed(row.before_duration_ms),
          Formatting.fixed(row.after_duration_ms),
          Formatting.signed_fixed(row.duration_diff_ms),
          percent(row.duration_change_percent)
        ]
      end

      widths = headings.each_index.map do |index|
        ([headings[index]] + body.map { |columns| columns[index] }).map(&:length).max
      end

      lines = []
      lines << format_row(headings, widths)
      lines << widths.map { |width| "-" * width }.join("-+-")
      body.each { |columns| lines << format_row(columns, widths) }
      lines.join("\n")
    end

    def format_row(columns, widths)
      columns.each_with_index.map do |value, index|
        index.zero? ? value.ljust(widths[index]) : value.rjust(widths[index])
      end.join(" | ")
    end

    # "-" marks a missing baseline (before count/duration was zero), which is a
    # table rule rather than number formatting, so it stays here.
    def percent(value)
      value ? Formatting.signed_percent(value) : "-"
    end
  end
end
