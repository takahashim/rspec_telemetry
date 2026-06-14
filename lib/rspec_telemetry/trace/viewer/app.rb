# frozen_string_literal: true

require "tui_tui"

require_relative "document"
require_relative "theme"
require_relative "layout"
require_relative "pane_resizer"
require_relative "source_view"
require_relative "app_renderer"
require_relative "screen/timeline_screen"
require_relative "screen/ranked_screen"

module RSpecTelemetry
  module Trace
    module Viewer
      # Hosts shared TUI state; per-screen row behavior lives in Screen strategies.
      class App
        WHEEL_ROWS = 3
        REDRAW = "\f"
        SPINNER = %w[| / - \\].freeze

        HELP = [
          ["1 / 2 / 3", "timeline / slowest examples / factories"],
          ["j / k   ↑ / ↓", "move"],
          ["Space / b", "page down / up"],
          ["g / G", "top / bottom"],
          ["n / N", "next / prev failure (timeline)"],
          ["Tab", "switch pane"],
          ["J / K", "scroll detail"],
          ["Enter", "fold / unfold this example"],
          ["z", "collapse to examples / expand"],
          ["f", "toggle follow"],
          ["/", "filter timeline"],
          ["a", "jump to example"],
          ["s", "toggle source pane"],
          ["S", "view full source"],
          ["mouse", "drag the divider / source header; wheel scrolls; click to focus"],
          ["Ctrl-L", "redraw the screen"],
          ["?", "this help"],
          ["q", "quit"]
        ].freeze

        attr_reader :detail_scroll, :follow

        def focus = @focus_ring.current

        def initialize(
          document,
          depth: TuiTui::ColorDepth.detect,
          source: nil,
          follow: false,
          base_dir: nil,
          source_root: Dir.pwd
        )
          @document = document
          @source = source
          @follow = follow
          @source_view = SourceView.new(source_root: source_root, base_dir: base_dir)
          @renderer = AppRenderer.new
          @list = TuiTui::ScrollList.new
          @detail_scroll = 0
          @focus_ring = TuiTui::FocusRing.new(:timeline, :detail)
          @spin = 0
          @stick = follow
          @modal = nil
          @on_result = nil
          @quit_armed = false
          @resizer = PaneResizer.new
          @size = nil
          @source_visible = true
          @view = :timeline
          @timeline_screen = Screen::TimelineScreen.new(@document, @list)
          @screen = @timeline_screen
        end

        def cursor = @list.cursor

        def wants_tick? = @follow

        def redraw?(event) = event.is_a?(TuiTui::KeyEvent) && event.key == REDRAW

        def update(event)
          case event
          when TuiTui::KeyEvent
            @modal ? route_modal(event) : handle_key_event(event)
          when TuiTui::MouseEvent
            @modal ? self : handle_mouse(event)
          when TuiTui::ResizeEvent
            (@size = event.size) && self
          when TuiTui::TickEvent
            poll
          else
            self
          end
        end

        def view(size)
          @size = size
          r = layout(size)
          result = @renderer.render(render_state(size, r))
          @detail_scroll = result.detail_scroll
          result.canvas
        end

        def layout(size)
          # Draw and hit-testing both use this geometry to keep mouse handles aligned.
          Layout.compute(
            size: size,
            want_time_bar: @screen.time_bar? && !@document.end_wall_ms.nil?,
            want_source: @screen.source? && @source_visible,
            split_ratio: @resizer.split_ratio,
            source_rows: @resizer.source_rows
          )
        end

        def open_modal(widget, &on_result)
          @modal = widget
          @on_result = on_result
        end

        def go_to(index)
          @list.go_to(index)
          @detail_scroll = 0
          # Follow resumes only when the cursor is still parked at the tail.
          @stick = @follow && @list.at_end?
        end

        private

        def route_modal(event)
          result = @modal.handle(event.key)
          return self if result.nil?

          @modal = nil
          @on_result.call(result) == :quit ? :quit : self
        end

        def confirm_quit
          open_modal(TuiTui::Confirm.new("Quit the trace viewer?", theme: Theme.base)) { |r| :quit if r == :ok }
        end

        def handle_key_event(event)
          armed = @quit_armed
          @quit_armed = false

          case event.key
          when TuiTui::KeyCode::CTRL_C
            # A second consecutive Ctrl-C exits without opening the quit modal.
            return :quit if armed

            @quit_armed = true
          when "q"
            confirm_quit
          when "?"
            open_modal(TuiTui::Help.new("Keys", HELP, theme: Theme.base)) { nil }
          when "1"
            set_view(:timeline)
          when "2"
            set_view(:examples)
          when "3"
            set_view(:factories)
          when "s"
            @source_visible = !@source_visible
          when "S"
            view_source
          when "j", :down
            move(1)
          when "k", :up
            move(-1)
          when " ", :pgdn
            move(page_rows)
          when "b", :pgup
            move(-page_rows)
          when "g", :home
            go_to(0)
          when "G", :end
            go_to(@list.last)
          when "\t", :backtab
            toggle_focus
          when "f"
            toggle_follow
          when "J"
            @detail_scroll += 1
          when "K"
            @detail_scroll = [@detail_scroll - 1, 0].max
          else
            @screen.handle_key_event(event, self)
          end

          self
        end

        def set_view(view)
          return if view == @view

          @view = view
          @screen = view == :timeline ? @timeline_screen : Screen::RankedScreen.new(@document, @list, view)
          @screen.activate
          go_to(0)
        end

        def move(delta) = go_to(@list.cursor + delta)

        def page_rows = @size ? [layout(@size).list.rows, 1].max : 1

        def toggle_focus
          @focus_ring = @focus_ring.next
        end

        def handle_mouse(event)
          if event.action == :wheel
            move(event.button == :wheel_up ? -WHEEL_ROWS : WHEEL_ROWS)
          elsif @size
            target = @resizer.handle(event, layout(@size))
            @focus_ring = @focus_ring.focus(target) if target
          end

          self
        end

        def toggle_follow
          @follow = !@follow
          @stick = @follow && @list.at_end?
        end

        def poll
          return self unless @follow

          # TickEvent drives both live ingestion and the pending spinner.
          @spin += 1
          ingest(@source.drain) if @source
          @list.to_end if @stick
          self
        end

        def ingest(lines)
          return if lines.empty?

          lines.each { |line| @document.apply(line) }
          @screen.refresh
        end

        def spinner = SPINNER[@spin % SPINNER.length]

        def view_source
          pager = @source_view.pager(@screen.current_source)
          open_modal(pager) { nil } if pager
        end

        def position
          count = @screen.count
          return "0/0" if count.zero?

          "#{@list.cursor + 1}/#{count}"
        end

        def render_state(size, regions)
          AppRenderer::State.new(
            size: size,
            regions: regions,
            document: @document,
            screen: @screen,
            list: @list,
            focus_ring: @focus_ring,
            source_view: @source_view,
            modal: @modal,
            detail_scroll: @detail_scroll,
            quit_armed: @quit_armed,
            follow: @follow,
            spinner: spinner,
            position: position
          )
        end
      end
    end
  end
end
