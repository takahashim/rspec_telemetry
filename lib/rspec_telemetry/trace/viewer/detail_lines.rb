# frozen_string_literal: true

require_relative "document"
require_relative "label"
require_relative "format"
require "tui_tui"

module RSpecTelemetry
  module Trace
    module Viewer
      module DetailLines
        def self.for(entry, children: [], duration: nil, width: nil)
          return [] if entry.nil?

          lines = if entry.is_a?(Document::Action)
            example_lines(entry, children, duration)
          else
            event_lines(entry)
          end

          return lines if width.nil?

          lines.flat_map { |line| TuiTui::DisplayText.new(line).wrap(width, indent: "  ").map(&:to_s) }
        end

        def self.example_lines(action, children, duration)
          lines = ["EXAMPLE", "desc: #{action.label}"]
          lines << "at: #{action.source}" if action.source
          lines << "status: #{action.status}" if action.status
          took = action.duration_ms || duration
          lines << "took: #{Format.ms(took)}" if took
          lines.concat(exception_lines(action.exception))
          lines.concat(children_lines(children))
          lines
        end

        def self.exception_lines(exception)
          return [] if exception.nil?

          ["", "exception: #{exception["class"]}", "  #{exception["message"]}"]
        end

        def self.children_lines(children)
          return [] if children.empty?

          total = children.sum { |e| (e.fields["self_duration_ms"] || e.fields["duration_ms"]).to_f }
          header = "ran #{children.size} factor#{children.size == 1 ? "y" : "ies"} (self #{Format.ms(total)}):"
          [""] + [header] + children.map { |event| "  #{Label.plain(event)}" }
        end

        def self.event_lines(event)
          lines = [Label.plain(event), ""]
          event.fields.each do |key, value|
            next if Document::INFRA_FIELDS.include?(key)

            lines.concat(field_lines(key, value))
          end

          lines
        end

        def self.field_lines(key, value)
          case value
          when Hash
            ["#{key}:"] + value.map { |k, v| "  #{k}: #{v.inspect}" }
          when Array
            ["#{key}:"] + value.map { |v| "  - #{v.inspect}" }
          else
            ["#{key}: #{value.inspect}"]
          end
        end
      end
    end
  end
end
