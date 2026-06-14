# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # The ranked report screens: 2 = slowest examples, 3 = factories by self
      # time. Switching, ranking order, navigation, detail, and back to 1.
      RSpec.describe App do
        include Fixtures

        def lines
          [
            started(id: "a", file: nil, desc: "fast one"),
            factory(name: "user", ex: "a", dur: 2.0),
            finished(id: "a", file: nil, status: "passed", dur: 10.0),
            started(id: "b", file: nil, desc: "slow one"),
            factory(name: "user", ex: "b", dur: 3.0),
            factory(name: "order", ex: "b", depth: 0, dur: 9.0, self_ms: 4.0),
            finished(id: "b", file: nil, status: "failed", dur: 200.0, exc: ["E", "boom"]),
            suite(examples: 2, failures: 1)
          ]
        end

        def app = App.new(Document.from_lines(lines), depth: :ansi256)
        def key(k) = TuiTui::KeyEvent.new(key: k)
        def size = TuiTui::Size.new(rows: 16, cols: 78)
        def screen(a) = (1..size.rows).map { |r| a.view(size).render_row(r, enabled: false) }.join("\n")

        it "2 shows examples slowest first" do
          a = app
          a.update(key("2"))
          shown = screen(a)
          expect(shown).to include("slow one")
          expect(shown).to include("fast one")
          # the slow example (200ms) is ranked above the fast one (10ms)
          expect(shown.index("slow one")).to be < shown.index("fast one")
          expect(shown).to include("[FAILED]")
        end

        it "3 shows factories by self time" do
          a = app
          a.update(key("3"))
          shown = screen(a)
          # user: 3 calls? here 2 calls (a,b) self 5ms total; order self 4ms.
          expect(shown).to include("user:create")
          expect(shown).to include("order:create")
          # user self (2+3=5ms) ranks above order self (4ms)
          expect(shown.index("user:create")).to be < shown.index("order:create")
        end

        it "status bar labels the current view" do
          a = app
          a.update(key("2"))
          expect(screen(a)).to include("[slowest examples]")
          a.update(key("3"))
          expect(screen(a)).to include("[factories by self time]")
        end

        it "navigation and detail on the factory report" do
          a = app
          a.update(key("3"))
          expect(a.cursor).to eq(0)
          a.update(key("j"))
          # moved to order:create
          expect(a.cursor).to eq(1)
          detail = screen(a)
          expect(detail).to include("FACTORY order:create")
          expect(detail).to include("self total:")
          expect(detail).to include("total:")
        end

        it "examples report detail shows failure" do
          a = app
          # cursor on the slowest = the failed example
          a.update(key("2"))
          detail = screen(a)
          expect(detail).to include("status: failed")
          expect(detail).to include("boom")
        end

        it "1 returns to the timeline" do
          a = app
          a.update(key("2"))
          a.update(key("1"))
          shown = screen(a)
          # timeline grouping is back
          expect(shown).to include("EXAMPLE fast one")
          expect(shown).to include("FACTORY user:create")
        end

        it "switching view resets the cursor" do
          a = app
          a.update(key("2"))
          # jump to bottom
          a.update(key("G"))
          expect(a.cursor).to be > 0
          # switching resets to top
          a.update(key("3"))
          expect(a.cursor).to eq(0)
        end
      end
    end
  end
end
