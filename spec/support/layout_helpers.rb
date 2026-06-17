# frozen_string_literal: true

# Builders for the pure Layout.compute geometry function, so layout specs pass
# sizes/options as arguments without defining methods in the spec file.
module LayoutHelpers
  def size(rows, cols) = TuiTui::Size.new(rows: rows, cols: cols)

  def compute(rows:, cols:, time: false, source: false, ratio: 0.5, source_rows: 10)
    RSpecTelemetry::Trace::Viewer::Layout.compute(
      size: size(rows, cols),
      want_time_bar: time,
      want_source: source,
      split_ratio: ratio,
      source_rows: source_rows
    )
  end
end
