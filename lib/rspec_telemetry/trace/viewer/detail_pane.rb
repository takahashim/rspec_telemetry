# frozen_string_literal: true

require_relative "theme"

module RSpecTelemetry
  module Trace
    module Viewer
      class DetailPane
        def initialize(lines, scroll:)
          @lines = lines
          @scroll = scroll
        end

        def length = @lines.length

        def draw(canvas, rect)
          TuiTui::TextView.draw(canvas, rect, top: @scroll, scrollbar: Theme.base, total: @lines.length) do |index|
            line = @lines[index]
            next nil if line.nil?

            style = index.zero? ? Theme.style(:action) : Theme.style(:dim)
            TuiTui::Line[TuiTui::Span[line, style]]
          end
        end
      end
    end
  end
end
