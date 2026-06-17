# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # Navigation (update) and layout (view) for the interactive viewer. Both are
      # exercised without a terminal: update folds a synthetic key, view returns a
      # Canvas whose rows are inspected.
      RSpec.describe App do
        # file: nil keeps the always-on source strip out of the way so the row
        # assertions below see the timeline/detail directly.
        let(:lines) do
          [
            started(id: "a", file: nil, desc: "User admin"),
            factory(name: "user", ex: "a", traits: ["admin"], dur: 5.0),
            finished(id: "a", file: nil, status: "passed", dur: 5.0),
            started(id: "b", file: nil, desc: "User order"),
            factory(name: "user", ex: "b", depth: 1, parent: "order", dur: 4.0),
            factory(name: "order", ex: "b", depth: 0, dur: 7.0, self_ms: 3.0),
            finished(id: "b", file: nil, status: "failed", dur: 9.0, exc: ["RSpec::ExpectationNotMet", "boom"]),
            suite(examples: 2, failures: 1)
          ]
        end
        # entries: 0 example(a) 1 factory(user) 2 example(b) 3 factory(user) 4 factory(order)

        let(:app) { App.new(Document.from_lines(lines), depth: :ansi256) }
        let(:size) { TuiTui::Size.new(rows: 16, cols: 80) }
        let(:ctx) { render_context(size) }

        it "starts at top focused on timeline" do
          a = app
          expect(a.cursor).to eq(0)
          expect(a.focus).to eq(:timeline)
        end

        it "draws Unicode chrome when the RenderContext reports box-drawing support" do
          a = app
          ctx = TuiTui::RenderContext.new(size: size, chrome: TuiTui::BoxChrome::UNICODE)
          rows = (1..size.rows).map { |r| a.view(ctx).render_row(r, enabled: false) }.join("\n")
          # the two-pane divider follows the chrome
          expect(rows).to include("│")
          expect(rows).not_to include("|")
        end

        it "falls back to an ASCII divider with a bare Size (no chrome)" do
          expect(screen(app)).to include("|")
        end

        it "down and up move the cursor" do
          a = app
          a.update(key("j"))
          expect(a.cursor).to eq(1)
          a.update(key(:down))
          expect(a.cursor).to eq(2)
          a.update(key("k"))
          expect(a.cursor).to eq(1)
        end

        it "up clamps at top" do
          a = app
          a.update(key("k"))
          expect(a.cursor).to eq(0)
        end

        it "g and capital g jump to ends" do
          a = app
          a.update(key("G"))
          expect(a.cursor).to eq(4)
          a.update(key("g"))
          expect(a.cursor).to eq(0)
        end

        it "space and b page by the viewport height" do
          a = app
          # establishes @size for page math
          a.view(ctx)
          rows = a.layout(size).list.rows
          a.update(key(" "))
          # clamped to the last entry
          expect(a.cursor).to eq([rows, 4].min)
          a.update(key("b"))
          expect(a.cursor).to eq(0)
        end

        it "resize sets the size used for paging (no view needed first)" do
          a = app
          a.update(TuiTui::ResizeEvent.new(size: size))
          a.update(key(" "))
          expect(a.cursor).to be > 0
        end

        it "n jumps to the failed example" do
          a = app
          a.update(key("n"))
          # the failed example
          expect(a.cursor).to eq(2)
        end

        it "tab toggles focus" do
          a = app
          a.update(key("\t"))
          expect(a.focus).to eq(:detail)
          a.update(key("\t"))
          expect(a.focus).to eq(:timeline)
        end

        it "quit is confirmed" do
          a = app
          # opens the confirm dialog
          expect(a.update(key("q"))).not_to eq(:quit)
          # y confirms -> quit
          expect(a.update(key("y"))).to eq(:quit)
        end

        it "ctrl c twice quits" do
          a = app
          expect(a.update(key(TuiTui::KeyCode::CTRL_C))).not_to eq(:quit)
          expect(a.update(key(TuiTui::KeyCode::CTRL_C))).to eq(:quit)
        end

        it "other key disarms ctrl c" do
          a = app
          a.update(key(TuiTui::KeyCode::CTRL_C))
          a.update(key("j"))
          expect(a.update(key(TuiTui::KeyCode::CTRL_C))).not_to eq(:quit)
        end

        it "armed ctrl c shows a hint" do
          a = app
          a.update(key(TuiTui::KeyCode::CTRL_C))
          row = a.view(ctx).render_row(size.rows, enabled: false)
          expect(row).to include("Ctrl-C again to quit")
        end

        it "redraw? identifies Ctrl-L (full-repaint request)" do
          a = app
          expect(a.redraw?(key("\f"))).to be_truthy
          expect(a.redraw?(key("j"))).to be_falsey
          expect(a.redraw?(TuiTui::TickEvent.new)).to be_falsey
        end

        it "filter limits the timeline" do
          a = app
          a.update(key("/"))
          "order:create".each_char { |c| a.update(key(c)) }
          a.update(key("\r"))
          expect(a.cursor).to eq(0)
          shown = screen(a)
          expect(shown).to include("FACTORY order:create")
          expect(shown).not_to include("EXAMPLE User admin")
        end

        it "filter modal is drawn over the timeline" do
          a = app
          a.update(key("/"))
          expect(screen(a)).to include("Filter:")
        end

        it "help overlay opens" do
          tall = TuiTui::Size.new(rows: 22, cols: 80)
          tall_ctx = TuiTui::RenderContext.new(size: tall, chrome: TuiTui::BoxChrome::ASCII)
          a = app
          a.update(key("?"))
          expect(screen(a, tall_ctx)).to include("this help")
          a.update(key("x"))
          expect(screen(a, tall_ctx)).not_to include("this help")
        end

        it "example detail shows the source line" do
          doc = Document.from_lines(
            [
              started(id: "a", file: "spec/posts_spec.rb", line: 12, desc: "creates"),
              factory(name: "user", ex: "a"),
              finished(id: "a", file: "spec/posts_spec.rb", line: 12, status: "passed"),
              suite(examples: 1)
            ]
          )
          a = App.new(doc, depth: :ansi256)
          expect(screen(a)).to include("at: spec/posts_spec.rb:12")
        end

        it "example jump selects an example" do
          a = app
          # open the jump menu (examples)
          a.update(key("a"))
          # second example (b)
          a.update(key(:down))
          a.update(key("\r"))
          expect(a.cursor).to eq(2)
        end

        it "view returns a canvas of the requested size" do
          size = TuiTui::Size.new(rows: 10, cols: 80)
          ctx = TuiTui::RenderContext.new(size: size, chrome: TuiTui::BoxChrome::ASCII)
          canvas = app.view(ctx)
          expect(canvas.rows).to eq(10)
          expect(canvas.cols).to eq(80)
        end

        it "view shows the timeline" do
          expect(app.view(ctx).render_row(1, enabled: false)).to include("EXAMPLE User admin")
        end

        it "selected row is drawn with the selection style" do
          canvas = app.view(ctx)
          styles = (1..canvas.cols).map { |c| canvas.cell(1, c)&.style }
          expect(styles).to include(RSpecTelemetry::Trace::Viewer::Theme::SELECT)
        end

        it "status bar shows count and position" do
          row = app.view(ctx).render_row(size.rows, enabled: false)
          expect(row).to include("3 events  failed")
          expect(row).to include("1/5")
        end

        it "detail pane shows the failed example" do
          a = app
          # select the failed example
          a.update(key("n"))
          detail = screen(a)
          expect(detail).to include("status: failed")
          expect(detail).to include("boom")
        end

        it "narrow terminal hides detail pane" do
          size = TuiTui::Size.new(rows: 10, cols: 40)
          ctx = TuiTui::RenderContext.new(size: size, chrome: TuiTui::BoxChrome::ASCII)
          canvas = app.view(ctx)
          expect(canvas.render_row(1, enabled: false)).to include("EXAMPLE User admin")
        end

        describe "mouse" do
          it "wheel scrolls the list" do
            a = app
            a.update(mouse(:wheel, 5, 5, button: :wheel_down))
            # WHEEL_ROWS
            expect(a.cursor).to eq(3)
            a.update(mouse(:wheel, 5, 5, button: :wheel_up))
            expect(a.cursor).to eq(0)
          end

          it "clicking a pane focuses it" do
            a = app
            # establish pane geometry
            a.view(ctx)
            detail = a.layout(size).detail
            # inside the detail pane
            a.update(mouse(:press, detail.col + 2, 3))
            expect(a.focus).to eq(:detail)

            list = a.layout(size).list
            # inside the list pane
            a.update(mouse(:press, list.col + 2, 3))
            expect(a.focus).to eq(:timeline)
          end

          it "dragging the divider resizes the panes, and release ends the drag" do
            a = app
            a.view(ctx)
            divider = a.layout(size).divider

            # grab the divider
            a.update(mouse(:press, divider, 3))
            # drag left
            a.update(mouse(:drag, divider - 10, 3))
            moved = a.layout(size).divider
            expect(moved).to be < divider

            a.update(mouse(:release, divider - 10, 3))
            # ignored: no button held
            a.update(mouse(:drag, divider - 20, 3))
            expect(a.layout(size).divider).to eq(moved)
          end

          it "a drag that did not grab a handle moves nothing" do
            a = app
            a.view(ctx)
            divider = a.layout(size).divider
            # never pressed a handle first
            a.update(mouse(:drag, divider - 10, 3))
            expect(a.layout(size).divider).to eq(divider)
          end

          it "dragging the source header resizes the source strip" do
            doc = Document.from_lines(
              [
                started(id: "a", file: "spec/posts_spec.rb", line: 12, desc: "creates"),
                factory(name: "user", ex: "a"),
                finished(id: "a", file: "spec/posts_spec.rb", line: 12, status: "passed"),
                suite(examples: 1)
              ]
            )
            a = App.new(doc, depth: :ansi256)
            tall = TuiTui::Size.new(rows: 24, cols: 80)
            tall_ctx = TuiTui::RenderContext.new(size: tall, chrome: TuiTui::BoxChrome::ASCII)
            a.view(tall_ctx)
            header = a.layout(tall).source_top
            before = a.layout(tall).source.rows
            expect(header).not_to be_nil

            # grab the source header
            a.update(mouse(:press, 40, header))
            # drag up -> taller strip
            a.update(mouse(:drag, 40, header - 3))
            expect(a.layout(tall).source.rows).to be > before
            expect(a.layout(tall).source_top).to be < header
          end

          it "does not collapse a pane below the minimum" do
            a = app
            a.view(ctx)
            a.update(mouse(:press, a.layout(size).divider, 3))
            # drag far past the left edge
            a.update(mouse(:drag, -100, 3))
            expect(a.layout(size).list.cols).to be >= Layout::MIN_PANE_COLS
          end

          it "draws a visible divider at the grab column" do
            a = app
            canvas = a.view(ctx)
            divider = a.layout(size).divider
            expect(canvas.cell(1, divider).char).to eq("|")
          end

          it "mouse events are ignored while a modal is open" do
            a = app
            # open help modal
            a.update(key("?"))
            expect(a.update(mouse(:wheel, 5, 5, button: :wheel_down))).to eq(a)
            # unchanged
            expect(a.cursor).to eq(0)
          end
        end
      end
    end
  end
end
