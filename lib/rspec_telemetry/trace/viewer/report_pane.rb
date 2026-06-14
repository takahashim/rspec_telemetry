# frozen_string_literal: true

require_relative "theme"

module RSpecTelemetry
  module Trace
    module Viewer
      class ReportPane
        def initialize(rows, list:, focus:)
          @rows = rows
          @list = list
          @focus = focus
        end

        def draw(canvas, rect)
          highlight = @focus ? Theme::SELECT : Theme::SELECT_BLUR
          TuiTui::List.new(@list).draw(canvas, rect, highlight: highlight, scrollbar: Theme.base) do |index, selected|
            row = @rows[index]
            style = selected ? highlight : Theme.style(row.style)
            TuiTui::Line[TuiTui::Span[row.text, style]]
          end
        end
      end
    end
  end
end
