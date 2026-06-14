# frozen_string_literal: true

require_relative "layout"

module RSpecTelemetry
  module Trace
    module Viewer
      # Owns mouse drag state and reports plain clicks back as focus targets.
      class PaneResizer
        DEFAULT_SOURCE_ROWS = 10

        attr_reader :split_ratio, :source_rows

        def initialize(split_ratio: 0.5, source_rows: DEFAULT_SOURCE_ROWS)
          @split_ratio = split_ratio
          @source_rows = source_rows
          @dragging = false
        end

        def handle(event, region)
          case event.action
          when :press
            return press(event, region)
          when :drag
            drag(event, region)
          when :release
            @dragging = false
          end

          nil
        end

        private

        def press(event, region)
          if on_source_header?(event.row, region)
            @dragging = :source
            nil
          elsif near_divider?(event.col, region)
            @dragging = :divider
            nil
          else
            focus_target(event.col, region)
          end
        end

        def drag(event, region)
          case @dragging
          when :divider
            drag_divider(event.col, region)
          when :source
            drag_source(event.row, region)
          end
        end

        def near_divider?(col, region)
          !region.divider.nil? && (col - region.divider).abs <= 1
        end

        def drag_divider(col, region)
          body = region.body
          return unless region.divider

          left_cols = (col - body.col).clamp(
            Layout::MIN_PANE_COLS,
            body.cols - Layout::MIN_PANE_COLS - Layout::GUTTER
          )
          @split_ratio = left_cols.to_f / body.cols
        end

        def on_source_header?(row, region)
          !region.source_top.nil? && row == region.source_top
        end

        def drag_source(row, region)
          content = region.content
          return unless content

          bottom = content.row + content.rows - 1
          @source_rows = (bottom - row + 1).clamp(
            Layout::MIN_SOURCE_ROWS,
            content.rows - Layout::MIN_BODY_ROWS
          )
        end

        def focus_target(col, region)
          return :timeline if in_rect?(region.list, col)
          return :detail if in_rect?(region.detail, col)

          nil
        end

        def in_rect?(rect, col)
          !rect.nil? && col >= rect.col && col < rect.col + rect.cols
        end
      end
    end
  end
end
