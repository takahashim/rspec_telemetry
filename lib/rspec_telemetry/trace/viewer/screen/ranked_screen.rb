# frozen_string_literal: true

require_relative "../document"
require_relative "../theme"
require_relative "../report_view"
require_relative "../report_pane"
require_relative "../detail_lines"

module RSpecTelemetry
  module Trace
    module Viewer
      module Screen
        class RankedScreen
          def initialize(document, list, view)
            @document = document
            @list = list
            @view = view
            refresh
          end

          def title = ReportView.title(@view)
          def time_bar? = false
          def time_bar_current = nil
          def count = @rows.size
          def source? = @view == :examples && @rows.any?(&:source)

          def activate = refresh

          def refresh
            @rows = ReportView.rows(@document, @view)
            @list.count = @rows.size
          end

          def draw_list(canvas, rect, focused:)
            ReportPane.new(@rows, list: @list, focus: focused).draw(canvas, rect)
          end

          def detail_lines(width)
            row = @rows[@list.cursor]
            return [] unless row

            if row.payload.is_a?(Document::Action)
              action = row.payload
              DetailLines.for(
                action,
                children: @document.events_for(action.seq),
                duration: action.duration_ms,
                width: width
              )
            else
              ReportView.detail(row.payload).flat_map do |line|
                TuiTui::DisplayText.new(line).wrap(width, indent: "  ").map(&:to_s)
              end
            end
          end

          def current_source
            @view == :examples ? @rows[@list.cursor]&.source : nil
          end

          def handle_key_event(_event, _app) = nil
        end
      end
    end
  end
end
