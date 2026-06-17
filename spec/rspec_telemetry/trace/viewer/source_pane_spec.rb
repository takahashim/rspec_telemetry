# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      RSpec.describe SourcePane do
        FILE = (1..10).map { |n| "code line #{n}" }.freeze

        let(:location) { "spec.rb:5" }
        let(:lines) { FILE }
        let(:target) { 5 }
        let(:rows) { 7 }
        let(:shown) do
          canvas = TuiTui::Canvas.blank(TuiTui::Size.new(rows: rows, cols: 40))
          rect = TuiTui::Rect.new(row: 1, col: 1, rows: rows, cols: 40)
          SourcePane.new(location: location, lines: lines, target: target).draw(canvas, rect)
          (1..rows).map { |r| canvas.render_row(r, enabled: false).rstrip }.join("\n")
        end

        it "header and marked line" do
          expect(shown).to include("source: spec.rb:5")
          expect(shown).to include("→    5  code line 5")
          # context around it
          expect(shown).to include("  4  code line 4")
        end

        context "with the target near the end and a short window" do
          let(:location) { "spec.rb:9" }
          let(:target) { 9 }
          let(:rows) { 5 }

          it "window centers on the target" do
            expect(shown).to include("→    9  code line 9")
            # scrolled down to the target
            expect(shown).not_to include("code line 2")
          end
        end

        context "when the file is missing" do
          let(:lines) { nil }

          it "is reported" do
            expect(shown).to include("(source not found)")
          end
        end

        context "with no recorded location" do
          let(:location) { nil }
          let(:lines) { nil }
          let(:target) { nil }

          it "shows a placeholder" do
            expect(shown).to include("no recorded source")
          end
        end
      end
    end
  end
end
