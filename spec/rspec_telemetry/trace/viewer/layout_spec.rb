# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # The pure geometry function shared by the renderer and mouse hit-testing.
      # No app state, no terminal — just size + a few values in, rects out.
      RSpec.describe Layout do
        def size(rows, cols) = TuiTui::Size.new(rows: rows, cols: cols)

        def compute(rows:, cols:, time: false, source: false, ratio: 0.5, source_rows: 10)
          Layout.compute(
            size: size(rows, cols),
            want_time_bar: time,
            want_source: source,
            split_ratio: ratio,
            source_rows: source_rows
          )
        end

        it "a tiny terminal collapses to a single region" do
          r = compute(rows: 1, cols: 80)
          expect(r.list.rows).to eq(1)
          expect(r.detail).to be_nil
          expect(r.divider).to be_nil
        end

        it "a narrow terminal hides the detail pane (single pane)" do
          r = compute(rows: 20, cols: 40)
          expect(r.detail).to be_nil
          expect(r.divider).to be_nil
          expect(r.list.cols).to eq(40)
        end

        it "a wide terminal splits into two panes with a divider in the gutter" do
          r = compute(rows: 20, cols: 80)
          expect(r.detail).not_to be_nil
          # divider sits just right of the list, with the detail one gutter beyond.
          expect(r.divider).to eq(r.list.col + r.list.cols)
          expect(r.detail.col).to eq(r.divider + Layout::GUTTER)
        end

        it "the split ratio drives the list width" do
          narrow = compute(rows: 20, cols: 100, ratio: 0.25)
          wide = compute(rows: 20, cols: 100, ratio: 0.75)
          expect(narrow.list.cols).to be < wide.list.cols
        end

        it "neither pane is clamped below the minimum at extreme ratios" do
          left = compute(rows: 20, cols: 80, ratio: 0.0)
          right = compute(rows: 20, cols: 80, ratio: 1.0)
          expect(left.list.cols).to be >= Layout::MIN_PANE_COLS
          expect(right.detail.cols).to be >= Layout::MIN_PANE_COLS
        end

        it "carves a time bar off the top when asked" do
          r = compute(rows: 20, cols: 80, time: true)
          expect(r.time.rows).to eq(1)
          expect(r.time.row).to eq(1)
          # body starts below the time bar
          expect(r.body.row).to eq(2)
        end

        it "carves a source strip and exposes its header row" do
          r = compute(rows: 24, cols: 80, source: true, source_rows: 8)
          expect(r.source.rows).to eq(8)
          expect(r.source_top).to eq(r.source.row)
          # body+source band kept for resize math
          expect(r.content).not_to be_nil
        end

        it "drops the source strip when there is no room for it and a body" do
          # below MIN_BODY+MIN_SOURCE+1
          r = compute(rows: 7, cols: 80, source: true)
          expect(r.source).to be_nil
          expect(r.source_top).to be_nil
        end

        it "clamps the source height so the body keeps its minimum" do
          r = compute(rows: 14, cols: 80, source: true, source_rows: 999)
          expect(r.body.rows).to be >= Layout::MIN_BODY_ROWS
          expect(r.source.rows).to be >= Layout::MIN_SOURCE_ROWS
        end
      end
    end
  end
end
