# frozen_string_literal: true

require_relative "theme"

module RSpecTelemetry
  module Trace
    module Viewer
      class SourcePane
        HEADER = TuiTui::Style.new(attrs: [:reverse])
        CODE = TuiTui::Style.new(attrs: [:dim])
        MARK = TuiTui::Style.new(fg: :green, attrs: [:bold])

        def initialize(location:, lines:, target:)
          @location = location
          @lines = lines
          @target = target
        end

        def draw(canvas, rect)
          canvas.fill(TuiTui::Rect.new(row: rect.row, col: rect.col, rows: 1, cols: rect.cols), HEADER)
          canvas.text(
            rect.row,
            rect.col,
            TuiTui::DisplayText.new(" source: #{@location || "(none for this step)"}").truncate(rect.cols),
            HEADER
          )

          avail = rect.rows - 1
          return canvas if avail < 1
          return placeholder(canvas, rect.row + 1, rect.col, rect.cols) if @lines.nil?

          body = TuiTui::Rect.new(row: rect.row + 1, col: rect.col, rows: avail, cols: rect.cols)
          draw_window(canvas, body)
          canvas
        end

        private

        def placeholder(canvas, row, col, cols)
          text = @location ? "(source not found)" : "(this step has no recorded source)"
          canvas.text(row, col, TuiTui::DisplayText.new("  #{text}").truncate(cols), CODE)
          canvas
        end

        def self.numbered_line(number, text, target:)
          "#{number == target ? "→" : " "} #{number.to_s.rjust(4)}  #{text}"
        end

        def draw_window(canvas, body)
          top = window_top(body.rows)
          TuiTui::TextView.draw(canvas, body, top: top) do |index|
            text = @lines[index]
            next nil if text.nil?

            number = index + 1
            line = self.class.numbered_line(number, text, target: @target)
            TuiTui::Line[TuiTui::Span[line, number == @target ? MARK : CODE]]
          end
        end

        def window_top(avail)
          return 0 if @target.nil?

          centered = @target - 1 - (avail / 2)
          centered.clamp(0, [@lines.size - avail, 0].max)
        end
      end
    end
  end
end
