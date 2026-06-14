# frozen_string_literal: true

require "set"

require_relative "../document"
require_relative "../theme"
require_relative "../label"
require_relative "../timeline_pane"
require_relative "../detail_lines"

module RSpecTelemetry
  module Trace
    module Viewer
      module Screen
        # Timeline-only state: filtering, folding, failure jumps, and live refresh.
        class TimelineScreen
          def initialize(document, list)
            @document = document
            @list = list
            @filter = nil
            @collapsed = Set.new
            rebuild
            compute_durations
          end

          def title = nil
          def time_bar? = true
          def source? = @document.actions.any?(&:source)
          def count = @visible.size

          def activate
            @collapsed.clear
            rebuild
            compute_durations
          end

          def refresh
            rebuild
            compute_durations
          end

          def draw_list(canvas, rect, focused:)
            TimelinePane
              .new(
                @visible,
                list: @list,
                focus: focused,
                collapsed: @collapsed,
                childful: @childful,
                durations: @durations
              )
              .draw(canvas, rect)
          end

          def detail_lines(width)
            entry = current_entry
            children = entry.is_a?(Document::Action) ? @document.events_for(entry.seq) : []
            duration = entry.is_a?(Document::Action) ? @durations[entry.seq] : nil
            DetailLines.for(entry, children: children, duration: duration, width: width)
          end

          def current_source
            entry = current_entry
            return entry.source if entry.is_a?(Document::Action)

            action = entry.is_a?(Document::Event) ? @document.action(entry.action) : nil
            action&.source
          end

          def time_bar_current
            entry = current_entry
            return nil if entry.nil?

            entry.is_a?(Document::Action) ? entry.wall_ms : entry.fields["wall_ms"]
          end

          def handle_key_event(event, app)
            case event.key
            when "/"
              open_filter(app)
            when "a"
              open_example_jump(app)
            when "n"
              jump_error(app, 1)
            when "N"
              jump_error(app, -1)
            when "\r"
              toggle_fold(app)
            when "z"
              toggle_all_folds(app)
            end
          end

          private

          def current_entry = @visible[@list.cursor]

          def rebuild
            base = filtered_entries
            @childful = base.filter_map { |entry| entry.action if entry.is_a?(Document::Event) }.to_set
            @visible = base.reject { |entry| entry.is_a?(Document::Event) && @collapsed.include?(entry.action) }
            @list.count = @visible.size
          end

          def filtered_entries
            return @document.entries unless @filter

            needle = @filter.downcase
            @document.entries.select { |entry| Label.plain(entry).downcase.include?(needle) }
          end

          def compute_durations
            actions = @document.entries.grep(Document::Action)
            @durations = {}
            actions.each_with_index do |action, index|
              # Running examples use the gap to the next example or stream end.
              @durations[action.seq] = if action.duration_ms
                action.duration_ms
              else
                finish = actions[index + 1]&.wall_ms || @document.end_wall_ms
                finish && action.wall_ms ? (finish - action.wall_ms) : nil
              end
            end
          end

          def open_filter(app)
            app.open_modal(TuiTui::Prompt.new("Filter:", value: @filter.to_s, theme: Theme.base)) do |result|
              apply_filter(app, result[1]) if result.is_a?(Array)
            end
          end

          def apply_filter(app, text)
            @filter = text.empty? ? nil : text
            rebuild
            app.go_to(0)
          end

          def open_example_jump(app)
            rows = @visible.each_index.select { |i| @visible[i].is_a?(Document::Action) }
            return if rows.empty?

            app
              .open_modal(
                TuiTui::Select.new("Jump to example", rows.map { |i| Label.plain(@visible[i]) }, theme: Theme.base)
              ) do |result|
                app.go_to(rows[result]) if result.is_a?(Integer)
              end
          end

          def jump_error(app, direction)
            index = @list.cursor + direction
            while index.between?(0, @list.last)
              entry = @visible[index]
              return app.go_to(index) if entry.is_a?(Document::Action) && %w[failed error].include?(entry.status)

              index += direction
            end
          end

          def toggle_fold(app)
            entry = current_entry
            seq = entry.is_a?(Document::Action) ? entry.seq : entry&.action
            return unless seq && @childful.include?(seq)

            @collapsed.include?(seq) ? @collapsed.delete(seq) : @collapsed.add(seq)
            rebuild
            index = @visible.index { |e| e.is_a?(Document::Action) && e.seq == seq }
            app.go_to(index) if index
          end

          def toggle_all_folds(app)
            @collapsed.empty? ? @collapsed.replace(@childful) : @collapsed.clear
            rebuild
            app.go_to(@list.cursor)
          end
        end
      end
    end
  end
end
