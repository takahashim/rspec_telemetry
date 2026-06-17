# frozen_string_literal: true

require "tui_tui"

module RSpecTelemetry
  module Trace
    module Viewer
      module Theme
        S = TuiTui::Style
        BASE = TuiTui::Theme.auto

        STYLES = {
          plain: BASE.text,
          action: S.new(attrs: [:bold]),
          dim: BASE.muted,
          error: S.new(fg: :red, attrs: [:bold]),
          ok: S.new(fg: :green)
        }.freeze

        SELECT = BASE.selection
        SELECT_BLUR = BASE.selection_dim
        BAR = BASE.bar

        def self.base = BASE

        def self.style(key) = STYLES.fetch(key)
      end
    end
  end
end
