# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # Folding examples into one-line steps, and the example-detail summary that
      # links a test to the factories it created.
      RSpec.describe App do
        include Fixtures

        def lines
          [
            started(id: "a", file: nil, desc: "User admin"),
            factory(name: "user", ex: "a", dur: 5.0),
            factory(name: "company", ex: "a", dur: 2.0),
            finished(id: "a", file: nil, status: "passed", dur: 8.0),
            started(id: "b", file: nil, desc: "Post create"),
            factory(name: "post", ex: "b", dur: 3.0),
            finished(id: "b", file: nil, status: "passed", dur: 3.0),
            suite(examples: 2)
          ]
        end
        # entries: 0 example(a) 1 factory(user) 2 factory(company) 3 example(b) 4 factory(post)

        def app = App.new(Document.from_lines(lines), depth: :ansi256)
        def key(k) = TuiTui::KeyEvent.new(key: k)
        # two panes
        def size = TuiTui::Size.new(rows: 14, cols: 70)
        # single pane (no detail)
        def narrow = TuiTui::Size.new(rows: 14, cols: 50)

        def timeline(a)
          canvas = a.view(narrow)
          (1..10).map { |r| canvas.render_row(r, enabled: false).rstrip }.join("\n")
        end

        it "enter folds the current step" do
          a = app
          expect(timeline(a)).to include("FACTORY user:create")
          # fold example a (cursor at 0)
          a.update(key("\r"))
          shown = timeline(a)
          expect(shown).not_to include("FACTORY user:create")
          expect(shown).to include("+ EXAMPLE User admin")
          expect(shown).to include("EXAMPLE Post create")
        end

        it "enter again unfolds" do
          a = app
          a.update(key("\r"))
          a.update(key("\r"))
          expect(timeline(a)).to include("FACTORY user:create")
          expect(timeline(a)).to include("- EXAMPLE User admin")
        end

        it "z collapses all to steps then expands" do
          a = app
          a.update(key("z"))
          shown = timeline(a)
          expect(shown).to include("EXAMPLE User admin")
          expect(shown).to include("EXAMPLE Post create")
          expect(shown).not_to include("FACTORY")
          a.update(key("z"))
          expect(timeline(a)).to include("FACTORY user:create")
        end

        it "fold keeps cursor on the example" do
          a = app
          # cursor onto the user factory under example a
          a.update(key("j"))
          # fold via the event -> anchors to its example
          a.update(key("\r"))
          expect(a.cursor).to eq(0)
          expect(timeline(a)).to include("+ EXAMPLE User admin")
        end

        it "example detail lists created factories" do
          # cursor on example a
          a = app
          detail = (1..14).map { |r| a.view(size).render_row(r, enabled: false) }.join("\n")
          expect(detail).to include("ran 2 factories")
          expect(detail).to include("FACTORY user:create")
          expect(detail).to include("FACTORY company:create")
        end

        it "examples without factories have no marker" do
          doc = Document.from_lines([started(id: "a", file: nil, desc: "noop"), finished(id: "a", file: nil), suite])
          a = App.new(doc, depth: :ansi256)
          row = a.view(size).render_row(1, enabled: false)
          expect(row).to include("EXAMPLE noop")
          expect(row).not_to include("+ EXAMPLE")
          expect(row).not_to include("- EXAMPLE")
        end
      end
    end
  end
end
