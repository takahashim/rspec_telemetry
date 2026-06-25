# frozen_string_literal: true

require_relative "formatting"

module RSpecTelemetry
  class ConsoleReport
    module Helpers
      module_function

      def fmt(ms) = Formatting.duration(ms)

      def pct(ratio) = Formatting.percent(ratio * 100)

      def truncate(str, len) = str.length > len ? "#{str[0, len - 1]}…" : str

      def section(title) = ["", title, "-" * title.length]
    end

    include Helpers

    def initialize(analyzer, files_count:, top: 15)
      @analyzer = analyzer
      @files_count = files_count
      @top = top
    end

    def render
      lines = overview + slow_files + slow_examples + top_factories
      lines << ""
      lines << "Tip: drill into one example with `rspec-telemetry --example \"<example_id>\"`"
      lines.join("\n")
    end

    def self.drill_down(events, example_id)
      lines = Helpers.section("Example: #{example_id}")
      finished = events.find { |e| e["type"] == "example.finished" }
      if finished
        lines << "  #{finished["full_description"]}"
        lines << "  status: #{finished["status"]}   duration: #{Helpers.fmt(finished["duration_ms"])}"
      end

      factories = events.select { |e| e["type"] == "factory_bot.run_factory" }
      return lines.join("\n") if factories.empty?

      lines << ""
      lines << "  FactoryBot calls (indented by nesting depth):"
      factories.each { |f| lines << factory_line(f) }
      total = factories.sum { |f| (f["self_duration_ms"] || f["duration_ms"]).to_f }
      lines << ""
      lines << "  factory self total: #{Helpers.fmt(total)} across #{factories.size} calls"
      lines.join("\n")
    end

    def self.factory_line(fields)
      indent = "    " + ("  " * fields["depth"].to_i)
      traits = Array(fields["traits"]).empty? ? "" : " [#{fields["traits"].join(",")}]"
      self_ms = fields["self_duration_ms"] || fields["duration_ms"]
      "#{indent}#{fields["factory"]}:#{fields["strategy"]}#{traits}  " \
        "self #{Helpers.fmt(self_ms)} / total #{Helpers.fmt(fields["duration_ms"])}"
    end

    private

    def overview
      a = @analyzer
      section("Overview") +
        [
          "  files analyzed:        #{@files_count}",
          "  examples:              #{a.example_count} (#{a.failure_count} failed, #{a.pending_count} pending)",
          "  suite wall time:       #{fmt(a.suite_duration_ms)}",
          "  example time (sum):    #{fmt(a.total_example_ms)}",
          "  factory self time:     #{fmt(a.total_factory_self_ms)} (#{pct(a.factory_time_ratio)} of example time)"
        ]
    end

    def slow_files
      rows = @analyzer.slow_files(@top)
      return [] if rows.empty?

      section("Slowest files (sum of example time)") +
        rows.each_with_index.map do |f, i|
          format("  %2d. %-9s %3d ex   %s", i + 1, fmt(f.duration_ms), f.example_count, f.file_path)
        end
    end

    def slow_examples
      rows = @analyzer.slow_examples(@top)
      return [] if rows.empty?

      lines = section("Slowest examples")
      rows.each_with_index do |e, i|
        fb = e.fb_count.to_i.positive? ? "  [factories: #{fmt(e.fb_self_total_ms)} / #{e.fb_count} calls]" : ""
        lines << format("  %2d. %-9s %s", i + 1, fmt(e.duration_ms), e.example_id)
        lines << "        #{e.full_description}#{fb}" if e.full_description || !fb.empty?
      end

      lines
    end

    def top_factories
      rows = @analyzer.top_factories(@top)
      return [] if rows.empty?

      lines = section("Slowest factories (by self time, excludes nested children)")
      lines << format("      %-28s %6s %10s %10s %9s %9s", "factory:strategy", "count", "self", "total", "avg", "max")
      rows.each_with_index do |f, i|
        lines <<
          format(
            "  %2d. %-28s %6d %10s %10s %9s %9s",
            i + 1,
            truncate(f.key, 28),
            f.count,
            fmt(f.self_total_ms),
            fmt(f.total_ms),
            fmt(f.avg_ms),
            fmt(f.max_ms)
          )
      end

      lines
    end
  end
end
