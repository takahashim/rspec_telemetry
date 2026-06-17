# frozen_string_literal: true

require "tui_tui"

require_relative "detail_pane"
require_relative "status_line"
require_relative "time_bar"

module RSpecTelemetry
  module Trace
    module Viewer
      class AppRenderer
        DIVIDER = TuiTui::Style.new(attrs: [:dim])

        State = Data.define(
          :size,
          :chrome,
          :regions,
          :document,
          :screen,
          :list,
          :focus_ring,
          :source_view,
          :modal,
          :detail_scroll,
          :quit_armed,
          :follow,
          :spinner,
          :position
        ) do
          def focused?(pane) = focus_ring.focused?(pane)
        end

        Result = Data.define(:canvas, :detail_scroll)

        def render(state)
          canvas = TuiTui::Canvas.blank(state.size, chrome: state.chrome)
          state.list.ensure_visible(state.regions.list.rows)

          TimeBar.new(current_ms: state.screen.time_bar_current, total_ms: state.document.end_wall_ms)
            .draw(canvas, state.regions.time) if state.regions.time
          state.screen.draw_list(canvas, state.regions.list, focused: state.focused?(:timeline))
          detail_scroll = draw_detail(canvas, state)
          draw_divider(canvas, state.regions) if state.regions.divider
          state.source_view.draw(canvas, state.regions.source, state.screen.current_source) if state.regions.source
          draw_status(canvas, state) if state.regions.status
          state.modal&.draw(canvas, state.size)

          Result.new(canvas: canvas, detail_scroll: detail_scroll || state.detail_scroll)
        end

        private

        def draw_detail(canvas, state)
          return nil unless state.regions.detail

          width = state.regions.detail.split_gutter.first.cols
          lines = state.screen.detail_lines(width)
          scroll = state.detail_scroll.clamp(0, [lines.length - 1, 0].max)
          DetailPane.new(lines, scroll: scroll).draw(canvas, state.regions.detail)
          scroll
        end

        def draw_divider(canvas, regions)
          body = regions.body
          rule = canvas.chrome.v
          body.rows.times { |dr| canvas.text(body.row + dr, regions.divider, rule, DIVIDER) }
        end

        def draw_status(canvas, state)
          notice = "Ctrl-C again to quit" if state.quit_armed
          StatusLine
            .new(
              state.document,
              position: state.position,
              notice: notice,
              total_ms: state.document.end_wall_ms,
              follow: state.follow,
              spinner: state.spinner,
              pending: state.document.pending?,
              mode: state.screen.title
            )
            .draw(canvas, state.regions.status)
        end
      end
    end
  end
end
