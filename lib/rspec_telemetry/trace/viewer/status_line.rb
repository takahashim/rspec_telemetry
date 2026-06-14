# frozen_string_literal: true

require_relative "theme"
require_relative "format"

module RSpecTelemetry
  module Trace
    module Viewer
      class StatusLine
        HINTS = "1-3=views  Tab=pane  f=follow  q=quit"

        def initialize(
          document,
          position:,
          follow: false,
          spinner: nil,
          pending: false,
          notice: nil,
          total_ms: nil,
          mode: nil
        )
          @document = document
          @position = position
          @follow = follow
          @spinner = spinner
          @pending = pending
          @notice = notice
          @total_ms = total_ms
          @mode = mode
        end

        def draw(canvas, rect)
          right = "#{@position}  #{@notice || HINTS} "
          TuiTui::StatusBar.draw(canvas, rect, left: left_text, right: right, style: Theme::BAR)
        end

        private

        def left_text
          text = @mode ? " [#{@mode}]  #{@document.status}" : " #{@document.events.size} events  #{@document.status}"
          total = Format.ms(@total_ms)
          text += "  #{total}" if total
          return text unless @follow

          text + "  follow #{@spinner}#{@pending ? " pending" : ""}"
        end
      end
    end
  end
end
