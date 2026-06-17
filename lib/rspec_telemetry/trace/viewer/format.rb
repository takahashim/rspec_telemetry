# frozen_string_literal: true

module RSpecTelemetry
  module Trace
    module Viewer
      module Format
        def self.ms(value)
          return nil if value.nil?

          value >= 1000 ? "#{(value / 1000.0).round(2)}s" : "#{value.round}ms"
        end

        # Inspect a value deterministically across Ruby versions (Ruby 3.4 changed
        # Hash#inspect from `{"k"=>v}` to `{"k" => v}`). Recurses into Hashes.
        def self.value(obj)
          return "{#{obj.map { |key, val| "#{key.inspect} => #{value(val)}" }.join(", ")}}" if obj.is_a?(Hash)

          obj.inspect
        end
      end
    end
  end
end
