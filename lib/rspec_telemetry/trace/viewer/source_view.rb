# frozen_string_literal: true

require "tui_tui"

require_relative "source_pane"
require_relative "source_resolver"
require_relative "theme"

module RSpecTelemetry
  module Trace
    module Viewer
      class SourceView
        def initialize(source_root:, base_dir:)
          @resolver = SourceResolver.new(source_root: source_root, base_dir: base_dir)
        end

        def draw(canvas, rect, location)
          file, target = source_location(location)
          SourcePane
            .new(location: location, lines: file && @resolver.lines_for(file), target: target)
            .draw(canvas, rect)
        end

        def pager(location)
          return nil unless location

          file, target = source_location(location)
          lines = numbered_source(@resolver.lines_for(file), target, file)
          TuiTui::Pager.new(
            "source: #{location}",
            lines,
            start: [target - 4, 0].max,
            close_keys: ["S"],
            theme: Theme.base
          )
        end

        private

        def source_location(location)
          return [nil, nil] unless location

          file, _, line = location.rpartition(":")
          [file, line.to_i]
        end

        def numbered_source(lines, target, file)
          if lines.nil?
            return [
              "(source not found: #{file})",
              "looked under: #{@resolver.roots.join(", ")}",
              "pass --source-root DIR to point at the project root"
            ]
          end

          lines.each_with_index.map do |text, index|
            SourcePane.numbered_line(index + 1, text, target: target)
          end
        end
      end
    end
  end
end
