# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # Follow mode: a TickEvent polls the source, folds new lines in, advances the
      # spinner, and keeps the cursor on the tail while stuck. A fake source feeds
      # batches so this needs no file or terminal.
      RSpec.describe App do
        include Fixtures

        # Hands out one queued batch of lines per drain, then nothing.
        class FakeSource
          def initialize(batches) = @batches = batches
          def drain = @batches.shift || []
        end

        def tick = TuiTui::TickEvent.new
        def key(k) = TuiTui::KeyEvent.new(key: k)
        def size = TuiTui::Size.new(rows: 10, cols: 80)

        def follow_app(*batches, start: [])
          document = Document.new
          start.each { |line| document.apply(line) }
          App.new(document, source: FakeSource.new(batches.dup), follow: true, depth: :ansi256)
        end

        it "tick folds in new lines" do
          app = follow_app(
            [
              started(id: "a", file: nil, desc: "User admin"),
              factory(name: "user", ex: "a")
            ]
          )
          app.update(tick)
          expect(app.view(size).render_row(1, enabled: false)).to include("EXAMPLE User admin")
        end

        it "cursor sticks to the tail while following" do
          app = follow_app(
            [started(id: "a", file: nil), factory(name: "user", ex: "a")],
            [factory(name: "order", ex: "a")]
          )
          app.update(tick)
          # parked on the newest of the first batch
          expect(app.cursor).to eq(1)
          app.update(tick)
          # followed the tail as it grew
          expect(app.cursor).to eq(2)
        end

        it "scrolling up detaches from the tail" do
          app = follow_app(
            [started(id: "a", file: nil), factory(name: "u1", ex: "a"), factory(name: "u2", ex: "a")],
            [factory(name: "u3", ex: "a")]
          )
          # cursor stuck at 2 (last of first batch)
          app.update(tick)
          # scroll up -> detach
          app.update(key("k"))
          expect(app.cursor).to eq(1)
          # new line arrives but we stay put
          app.update(tick)
          expect(app.cursor).to eq(1)
        end

        it "f toggles follow" do
          app = App.new(Document.new, depth: :ansi256)
          expect(app.follow).to be_falsey
          app.update(key("f"))
          expect(app.follow).to be_truthy
          app.update(key("f"))
          expect(app.follow).to be_falsey
        end

        it "status bar shows follow and pending" do
          app = follow_app([started(id: "a", file: nil), factory(name: "user", ex: "a")])
          app.update(tick)
          status = app.view(size).render_row(10, enabled: false)
          expect(status).to include("follow")
          # no suite.finished yet
          expect(status).to include("pending")
        end

        it "pending clears after suite finished" do
          app = follow_app(
            [started(id: "a", file: nil)],
            [finished(id: "a", file: nil), suite(examples: 1)]
          )
          app.update(tick)
          app.update(tick)
          expect(app.view(size).render_row(10, enabled: false)).not_to include("pending")
        end
      end
    end
  end
end
