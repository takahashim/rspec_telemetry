# frozen_string_literal: true

module RSpecTelemetry
  module Trace
    module Viewer
      module Format
        def self.ms(value)
          return nil if value.nil?

          value >= 1000 ? "#{(value / 1000.0).round(2)}s" : "#{value.round}ms"
        end
      end
    end
  end
end
