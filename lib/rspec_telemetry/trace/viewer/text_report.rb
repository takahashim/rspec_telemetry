# frozen_string_literal: true

require_relative "theme"
require_relative "label"

module RSpecTelemetry
  module Trace
    module Viewer
      class TextReport
        def initialize(document, depth: TuiTui::ColorDepth.detect, enabled: true)
          @document = document
          @depth = depth
          @enabled = enabled
        end

        def render
          @document.entries.map { |entry| render_entry(entry) }.join("\n")
        end

        def summary
          count = @document.events.size
          paint("#{count} events  #{@document.status}", status_style)
        end

        private

        def render_entry(entry)
          prefix = entry.is_a?(Document::Action) ? "" : "  "
          prefix + Label.segments(entry).map { |segment| paint(segment.text, segment.style) }.join
        end

        def paint(text, style_key)
          Theme.style(style_key).paint(text, depth: @depth, enabled: @enabled)
        end

        def status_style
          case @document.status
          when "failed", "error", "timeout"
            :error
          when "ok"
            :ok
          else
            :dim
          end
        end
      end
    end
  end
end
