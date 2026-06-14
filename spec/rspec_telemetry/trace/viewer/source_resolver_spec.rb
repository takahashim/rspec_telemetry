# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

module RSpecTelemetry
  module Trace
    module Viewer
      RSpec.describe SourceResolver do
        it "reads a file resolved under the explicit source_root" do
          Dir.mktmpdir do |root|
            File.write(File.join(root, "a_spec.rb"), "line1\nline2\n")
            resolver = described_class.new(source_root: root)
            expect(resolver.lines_for("a_spec.rb")).to eq(%w[line1 line2])
          end
        end

        it "falls back to the trace file's ancestors when source_root misses" do
          Dir.mktmpdir do |root|
            FileUtils.mkdir_p(File.join(root, "tmp"))
            FileUtils.mkdir_p(File.join(root, "spec"))
            File.write(File.join(root, "spec", "foo_spec.rb"), "it\n")
            # trace at <root>/tmp/run.ndjson, source_root unrelated
            resolver = described_class.new(source_root: "/nonexistent", base_dir: File.join(root, "tmp"))
            expect(resolver.lines_for("./spec/foo_spec.rb")).to eq(["it"])
            expect(resolver.roots).to include(root)
          end
        end

        it "returns nil for a missing file" do
          resolver = described_class.new(source_root: "/nonexistent")
          expect(resolver.lines_for("nope.rb")).to be_nil
        end

        it "caches the read (including the nil miss)" do
          Dir.mktmpdir do |root|
            path = File.join(root, "a_spec.rb")
            File.write(path, "one\n")
            resolver = described_class.new(source_root: root)
            expect(resolver.lines_for("a_spec.rb")).to eq(["one"])
            File.write(path, "changed\n")
            # served from cache
            expect(resolver.lines_for("a_spec.rb")).to eq(["one"])
          end
        end
      end
    end
  end
end
