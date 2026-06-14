# frozen_string_literal: true

require_relative "theme"
require_relative "label"
require_relative "format"

module RSpecTelemetry
  module Trace
    module Viewer
      class TimelinePane
        EXPANDED = "- "
        COLLAPSED = "+ "
        NO_CHILDREN = "  "
        EVENT_INDENT = "    "

        def initialize(entries, list:, focus:, collapsed: nil, childful: nil, durations: nil)
          @entries = entries
          @list = list
          @focus = focus
          @collapsed = collapsed || []
          @childful = childful || []
          @durations = durations || {}
        end

        def draw(canvas, rect)
          highlight = @focus ? Theme::SELECT : Theme::SELECT_BLUR
          TuiTui::List.new(@list).draw(canvas, rect, highlight: highlight, scrollbar: Theme.base) do |index, selected|
            entry = @entries[index]
            text = prefix(entry) + Label.plain(entry) + duration_suffix(entry)
            style = selected ? highlight : Theme.style(Label.category(entry))
            TuiTui::Line[TuiTui::Span[text, style]]
          end
        end

        private

        def prefix(entry)
          return EVENT_INDENT unless entry.is_a?(Document::Action)
          return NO_CHILDREN unless @childful.include?(entry.seq)

          @collapsed.include?(entry.seq) ? COLLAPSED : EXPANDED
        end

        def duration_suffix(entry)
          return "" unless entry.is_a?(Document::Action)

          formatted = Format.ms(@durations[entry.seq])
          formatted ? "  (#{formatted})" : ""
        end
      end
    end
  end
end
