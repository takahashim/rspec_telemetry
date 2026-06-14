# frozen_string_literal: true

require_relative "theme"
require_relative "format"

module RSpecTelemetry
  module Trace
    module Viewer
      class TimeBar
        LABEL = TuiTui::Style.new(attrs: [:bold])
        FILL = TuiTui::Style.new(fg: :green)
        TRACK = TuiTui::Style.new(attrs: [:dim])

        def initialize(current_ms:, total_ms:)
          @current = current_ms
          @total = total_ms
        end

        def draw(canvas, rect)
          canvas.fill(rect, TRACK)
          return canvas unless @total && @total.positive?

          current = (@current || 0).clamp(0, @total)
          percent = (current.to_f / @total * 100).round
          label = " #{Format.ms(current)} / #{Format.ms(@total)}  #{percent}% "
          canvas.text(rect.row, rect.col, label, LABEL)

          draw_bar(canvas, rect, current, TuiTui::DisplayText.new(label).width)
          canvas
        end

        private

        def draw_bar(canvas, rect, current, label_width)
          width = rect.cols - label_width
          return if width < 4

          col = rect.col + label_width
          filled = (current.to_f / @total * width).round
          canvas.text(rect.row, col, "=" * filled, FILL)
          canvas.text(rect.row, col + filled, "-" * (width - filled), TRACK)
        end
      end
    end
  end
end
