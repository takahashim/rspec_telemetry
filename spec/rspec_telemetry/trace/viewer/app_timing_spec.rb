# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # Real elapsed time: per-example durations in the timeline (RSpec run_time),
      # "took:" in the detail, and the total in the status bar / top bar — for
      # finding slow examples. wall_ms is synthesized from monotonic_time.
      RSpec.describe App do
        # t0 = 1000.0. example a runs 58ms; example b 1.14s; total wall 1.2s.
        let(:lines) do
          [
            started(id: "a", file: nil, desc: "fast", mono: 1000.002),
            finished(id: "a", file: nil, status: "passed", dur: 58.0, mono: 1000.06),
            started(id: "b", file: nil, desc: "slow", mono: 1000.06),
            factory(name: "order", ex: "b", dur: 800.0, mono: 1000.9),
            finished(id: "b", file: nil, status: "failed", dur: 1140.0, mono: 1001.14),
            suite(examples: 2, failures: 1, mono: 1001.2)
          ]
        end

        let(:app) { App.new(Document.from_lines(lines), depth: :ansi256) }
        let(:narrow) { render_context(TuiTui::Size.new(rows: 12, cols: 50)) }
        let(:wide) { render_context(TuiTui::Size.new(rows: 12, cols: 80)) }

        it "timeline shows per example durations" do
          a = app
          # steps view (examples only)
          a.update(key("z"))
          shown = (1..10).map { |r| a.view(narrow).render_row(r, enabled: false) }.join("\n")
          expect(shown).to include("EXAMPLE fast  (58ms)")
          expect(shown).to include("EXAMPLE slow [FAILED]  (1.14s)")
        end

        it "detail shows took for the selected example" do
          detail = (1..12).map { |r| app.view(wide).render_row(r, enabled: false) }.join("\n")
          expect(detail).to include("took: 58ms")
        end

        it "status bar shows total elapsed" do
          row = app.view(wide).render_row(12, enabled: false)
          expect(row).to include("1.2s")
        end

        it "top time bar tracks the cursor" do
          a = app
          # example a at 2ms
          expect(a.view(wide).render_row(1, enabled: false)).to include("0%")
          # last entry is the order factory at 900ms -> 75%
          a.update(key("G"))
          expect(a.view(wide).render_row(1, enabled: false)).to include("75%")
        end

        it "no time bar for an untimed stream" do
          doc = Document.from_lines([started(id: "a", file: nil, desc: "x"), finished(id: "a", file: nil), suite])
          a = App.new(doc, depth: :ansi256)
          expect(a.view(wide).render_row(1, enabled: false)).to include("EXAMPLE x")
        end

        it "no durations without timing" do
          # An example still running (no finished, no monotonic) shows no suffix.
          doc = Document.from_lines([started(id: "a", file: nil, desc: "x"), factory(name: "user", ex: "a")])
          a = App.new(doc, depth: :ansi256)
          row = a.view(narrow).render_row(1, enabled: false)
          expect(row).to include("EXAMPLE x")
          expect(row).not_to include("ms)")
        end
      end
    end
  end
end
