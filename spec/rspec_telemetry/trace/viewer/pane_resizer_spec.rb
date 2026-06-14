# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # The pointer-driven resize/focus logic, exercised directly against a Layout
      # region (no App, no terminal).
      RSpec.describe PaneResizer do
        def region(cols: 80, rows: 24, source: false)
          Layout.compute(
            size: TuiTui::Size.new(rows: rows, cols: cols),
            want_time_bar: false,
            want_source: source,
            split_ratio: 0.5,
            source_rows: 8
          )
        end

        def mouse(action, col, row, button: :left)
          TuiTui::MouseEvent.new(action: action, button: button, col: col, row: row)
        end

        it "dragging the divider changes the split ratio" do
          r = PaneResizer.new
          reg = region
          r.handle(mouse(:press, reg.divider, 3), reg)
          r.handle(mouse(:drag, reg.divider - 10, 3), reg)
          expect(r.split_ratio).to be < 0.5
        end

        it "release ends the drag (a later drag does nothing)" do
          r = PaneResizer.new
          reg = region
          r.handle(mouse(:press, reg.divider, 3), reg)
          r.handle(mouse(:release, reg.divider, 3), reg)
          before = r.split_ratio
          r.handle(mouse(:drag, reg.divider - 20, 3), reg)
          expect(r.split_ratio).to eq(before)
        end

        it "a drag without grabbing a handle does nothing" do
          r = PaneResizer.new
          reg = region
          r.handle(mouse(:drag, reg.divider - 10, 3), reg)
          expect(r.split_ratio).to eq(0.5)
        end

        it "clamps the divider so neither pane collapses" do
          r = PaneResizer.new
          reg = region
          r.handle(mouse(:press, reg.divider, 3), reg)
          # far past the left edge
          r.handle(mouse(:drag, -100, 3), reg)
          left_cols = (r.split_ratio * reg.body.cols).round
          expect(left_cols).to be >= Layout::MIN_PANE_COLS
        end

        it "dragging the source header changes the source height" do
          r = PaneResizer.new(source_rows: 6)
          reg = region(source: true)
          r.handle(mouse(:press, 40, reg.source_top), reg)
          # drag up -> taller
          r.handle(mouse(:drag, 40, reg.source_top - 3), reg)
          expect(r.source_rows).to be > 6
        end

        it "a plain click reports the pane it landed in" do
          r = PaneResizer.new
          reg = region
          expect(r.handle(mouse(:press, reg.list.col + 2, 3), reg)).to eq(:timeline)
          expect(r.handle(mouse(:press, reg.detail.col + 2, 3), reg)).to eq(:detail)
        end

        it "grabbing a handle is not a focus click (returns nil)" do
          r = PaneResizer.new
          reg = region
          expect(r.handle(mouse(:press, reg.divider, 3), reg)).to be_nil
        end
      end
    end
  end
end
