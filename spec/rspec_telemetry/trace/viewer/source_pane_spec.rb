# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      RSpec.describe SourcePane do
        FILE = (1..10).map { |n| "code line #{n}" }.freeze

        def rect(rows) = TuiTui::Rect.new(row: 1, col: 1, rows: rows, cols: 40)

        def render(location:, lines:, target:, rows: 7)
          canvas = TuiTui::Canvas.blank(TuiTui::Size.new(rows: rows, cols: 40))
          SourcePane.new(location: location, lines: lines, target: target).draw(canvas, rect(rows))
          (1..rows).map { |r| canvas.render_row(r, enabled: false).rstrip }.join("\n")
        end

        it "header and marked line" do
          shown = render(location: "spec.rb:5", lines: FILE, target: 5)
          expect(shown).to include("source: spec.rb:5")
          expect(shown).to include("→    5  code line 5")
          # context around it
          expect(shown).to include("  4  code line 4")
        end

        it "window centers on the target" do
          shown = render(location: "spec.rb:9", lines: FILE, target: 9, rows: 5)
          expect(shown).to include("→    9  code line 9")
          # scrolled down to the target
          expect(shown).not_to include("code line 2")
        end

        it "missing file is reported" do
          expect(render(location: "spec.rb:5", lines: nil, target: 5)).to include("(source not found)")
        end

        it "no location placeholder" do
          expect(render(location: nil, lines: nil, target: nil)).to include("no recorded source")
        end
      end
    end
  end
end
