# frozen_string_literal: true

require "tui_tui"

module RSpecTelemetry
  module Trace
    module Viewer
      # Pure geometry shared by rendering and mouse hit-testing.
      module Layout
        MIN_TWO_PANE = 60
        GUTTER = 1
        MIN_PANE_COLS = 12
        MIN_SOURCE_ROWS = 3
        MIN_BODY_ROWS = 4

        Regions = Data.define(
          :time,
          :body,
          :list,
          :detail,
          :divider,
          :source,
          :source_top,
          :content,
          :status
        )

        # Regions are nil when the terminal is too small or a feature is hidden.
        def self.compute(size:, want_time_bar:, want_source:, split_ratio:, source_rows:)
          return single(whole(size)) if size.rows < 2

          body, status = whole(size).split_h(size.rows - 1)
          time, body = carve_time_bar(body) if want_time_bar
          content, body, source, source_top = carve_source(body, source_rows) if want_source
          list, detail, divider = split_panes(body, split_ratio)

          Regions.new(
            time: time,
            body: body,
            list: list,
            detail: detail,
            divider: divider,
            source: source,
            source_top: source_top,
            content: content,
            status: status
          )
        end

        def self.source_height(content, source_rows)
          # Keep both source and main body usable while dragging.
          lo = MIN_SOURCE_ROWS
          hi = content.rows - MIN_BODY_ROWS
          return nil if hi < lo

          source_rows.clamp(lo, hi)
        end

        def self.single(body)
          Regions.new(
            time: nil,
            body: body,
            list: body,
            detail: nil,
            divider: nil,
            source: nil,
            source_top: nil,
            content: nil,
            status: nil
          )
        end

        def self.carve_time_bar(body)
          return [nil, body] if body.rows < 2

          body.split_h(1)
        end

        def self.carve_source(body, source_rows)
          return [nil, body, nil, nil] if body.rows < MIN_BODY_ROWS + MIN_SOURCE_ROWS + 1

          height = source_height(body, source_rows)
          return [nil, body, nil, nil] if height.nil?

          top, source = body.split_h(body.rows - height)
          [body, top, source, source.row]
        end

        def self.split_panes(body, ratio)
          return [body, nil, nil] if body.cols < MIN_TWO_PANE

          left, detail = body.split_ratio(ratio, min: MIN_PANE_COLS, gutter: GUTTER)
          [left, detail, left.col + left.cols]
        end

        def self.whole(size) = TuiTui::Rect.new(row: 1, col: 1, rows: size.rows, cols: size.cols)
      end
    end
  end
end
