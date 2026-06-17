# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # The pointer-driven resize/focus logic, exercised directly against a Layout
      # region (no App, no terminal).
      RSpec.describe PaneResizer do
        let(:cols) { 80 }
        let(:rows) { 24 }
        let(:source) { false }
        let(:resizer) { PaneResizer.new }
        let(:region) do
          Layout.compute(
            size: TuiTui::Size.new(rows: rows, cols: cols),
            want_time_bar: false,
            want_source: source,
            split_ratio: 0.5,
            source_rows: 8
          )
        end

        it "dragging the divider changes the split ratio" do
          resizer.handle(mouse(:press, region.divider, 3), region)
          resizer.handle(mouse(:drag, region.divider - 10, 3), region)
          expect(resizer.split_ratio).to be < 0.5
        end

        it "release ends the drag (a later drag does nothing)" do
          resizer.handle(mouse(:press, region.divider, 3), region)
          resizer.handle(mouse(:release, region.divider, 3), region)
          before = resizer.split_ratio
          resizer.handle(mouse(:drag, region.divider - 20, 3), region)
          expect(resizer.split_ratio).to eq(before)
        end

        it "a drag without grabbing a handle does nothing" do
          resizer.handle(mouse(:drag, region.divider - 10, 3), region)
          expect(resizer.split_ratio).to eq(0.5)
        end

        it "clamps the divider so neither pane collapses" do
          resizer.handle(mouse(:press, region.divider, 3), region)
          # far past the left edge
          resizer.handle(mouse(:drag, -100, 3), region)
          left_cols = (resizer.split_ratio * region.body.cols).round
          expect(left_cols).to be >= Layout::MIN_PANE_COLS
        end

        it "a plain click reports the pane it landed in" do
          expect(resizer.handle(mouse(:press, region.list.col + 2, 3), region)).to eq(:timeline)
          expect(resizer.handle(mouse(:press, region.detail.col + 2, 3), region)).to eq(:detail)
        end

        it "grabbing a handle is not a focus click (returns nil)" do
          expect(resizer.handle(mouse(:press, region.divider, 3), region)).to be_nil
        end

        context "with a source strip" do
          let(:source) { true }
          let(:resizer) { PaneResizer.new(source_rows: 6) }

          it "dragging the source header changes the source height" do
            resizer.handle(mouse(:press, 40, region.source_top), region)
            # drag up -> taller
            resizer.handle(mouse(:drag, 40, region.source_top - 3), region)
            expect(resizer.source_rows).to be > 6
          end
        end
      end
    end
  end
end
