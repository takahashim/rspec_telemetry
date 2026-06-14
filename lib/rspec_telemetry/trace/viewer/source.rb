# frozen_string_literal: true

module RSpecTelemetry
  module Trace
    module Viewer
      class TailSource
        def initialize(path)
          @path = path
          @offset = 0
          @partial = +""
        end

        def drain
          return [] unless File.file?(@path)

          reset_if_shrunk
          chunk = read_new_bytes
          return [] if chunk.empty?

          @partial << chunk
          split_complete_lines
        end

        private

        def reset_if_shrunk
          return unless File.size(@path) < @offset

          @offset = 0
          @partial = +""
        end

        def read_new_bytes
          return "" if File.size(@path) <= @offset

          File.open(@path, "rb") do |file|
            file.seek(@offset)
            data = file.read || ""
            @offset = file.pos
            data
          end
        end

        def split_complete_lines
          pieces = @partial.split("\n", -1)
          @partial = pieces.pop || +""
          pieces.map { |line| line.dup.force_encoding("UTF-8") }
        end
      end
    end
  end
end
