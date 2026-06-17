# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # Follow mode: a TickEvent polls the source, folds new lines in, advances the
      # spinner, and keeps the cursor on the tail while stuck. A fake source feeds
      # batches so this needs no file or terminal.
      RSpec.describe App do
        # Hands out one queued batch of lines per drain, then nothing.
        let(:fake_source_class) do
          Class
            .new do
            def initialize(batches) = @batches = batches
            def drain = @batches.shift || []
          end
        end

        let(:size) { TuiTui::Size.new(rows: 10, cols: 80) }
        let(:ctx) { render_context(size) }
        # Each element is one batch returned by a single drain (i.e. one tick).
        let(:batches) { [] }
        let(:app) { App.new(Document.new, source: fake_source_class.new(batches.dup), follow: true, depth: :ansi256) }

        context "with one batch (a started example and its factory)" do
          let(:batches) { [[started(id: "a", file: nil, desc: "User admin"), factory(name: "user", ex: "a")]] }

          it "tick folds in new lines" do
            app.update(tick)
            expect(app.view(ctx).render_row(1, enabled: false)).to include("EXAMPLE User admin")
          end
        end

        context "with two batches arriving over two ticks" do
          let(:batches) do
            [
              [started(id: "a", file: nil), factory(name: "user", ex: "a")],
              [factory(name: "order", ex: "a")]
            ]
          end

          it "cursor sticks to the tail while following" do
            app.update(tick)
            # parked on the newest of the first batch
            expect(app.cursor).to eq(1)
            app.update(tick)
            # followed the tail as it grew
            expect(app.cursor).to eq(2)
          end
        end

        context "when the cursor is scrolled up off the tail" do
          let(:batches) do
            [
              [started(id: "a", file: nil), factory(name: "u1", ex: "a"), factory(name: "u2", ex: "a")],
              [factory(name: "u3", ex: "a")]
            ]
          end

          it "detaches from the tail and stays put" do
            # cursor stuck at 2 (last of first batch)
            app.update(tick)
            # scroll up -> detach
            app.update(key("k"))
            expect(app.cursor).to eq(1)
            # new line arrives but we stay put
            app.update(tick)
            expect(app.cursor).to eq(1)
          end
        end

        context "with a pending suite (no suite.finished yet)" do
          let(:batches) { [[started(id: "a", file: nil), factory(name: "user", ex: "a")]] }

          it "status bar shows follow and pending" do
            app.update(tick)
            status = app.view(ctx).render_row(10, enabled: false)
            expect(status).to include("follow")
            expect(status).to include("pending")
          end
        end

        context "once the suite has finished" do
          let(:batches) do
            [
              [started(id: "a", file: nil)],
              [finished(id: "a", file: nil), suite(examples: 1)]
            ]
          end

          it "pending clears" do
            app.update(tick)
            app.update(tick)
            expect(app.view(ctx).render_row(10, enabled: false)).not_to include("pending")
          end
        end

        context "with no source" do
          let(:app) { App.new(Document.new, depth: :ansi256) }

          it "f toggles follow" do
            expect(app.follow).to be_falsey
            app.update(key("f"))
            expect(app.follow).to be_truthy
            app.update(key("f"))
            expect(app.follow).to be_falsey
          end
        end
      end
    end
  end
end
