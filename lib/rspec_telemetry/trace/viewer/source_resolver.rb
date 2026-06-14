# frozen_string_literal: true

module RSpecTelemetry
  module Trace
    module Viewer
      class SourceResolver
        ANCESTOR_DEPTH = 5

        def initialize(source_root:, base_dir: nil)
          @source_root = source_root
          @base_dir = base_dir
          @cache = {}
        end

        def lines_for(file)
          return @cache[file] if @cache.key?(file)

          @cache[file] = read(file)
        end

        def roots
          @roots ||= begin
            list = [@source_root]
            dir = @base_dir
            ANCESTOR_DEPTH.times do
              break if dir.nil?

              list << dir
              parent = ::File.dirname(dir)
              break if parent == dir

              dir = parent
            end

            list.compact.uniq
          end
        end

        private

        def read(file)
          roots.each do |root|
            path = ::File.expand_path(file, root)
            next unless ::File.file?(path)

            return ::File.readlines(path, chomp: true)
          rescue SystemCallError
            next
          end

          nil
        end
      end
    end
  end
end
