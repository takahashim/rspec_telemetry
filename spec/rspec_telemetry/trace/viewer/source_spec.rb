# frozen_string_literal: true

require "spec_helper"
require "tempfile"

module RSpecTelemetry
  module Trace
    module Viewer
      # Tailing: complete lines are returned, a partial trailing line is held back
      # until it finishes, appends are picked up incrementally, and a shrunk file
      # resets the read position.
      RSpec.describe TailSource do
        def with_file
          Tempfile.create(["trace", ".ndjson"]) do |file|
            file.sync = true
            yield file, TailSource.new(file.path)
          end
        end

        def append(file, text)
          file.write(text)
          file.flush
        end

        it "returns complete lines" do
          with_file do |file, source|
            append(file, "a\nb\n")
            expect(source.drain).to eq(%w[a b])
          end
        end

        it "holds back partial trailing line" do
          with_file do |file, source|
            append(file, "a\nb")
            # "b" has no newline yet
            expect(source.drain).to eq(["a"])
            append(file, "c\n")
            # completed on the next drain
            expect(source.drain).to eq(["bc"])
          end
        end

        it "drain is incremental" do
          with_file do |file, source|
            append(file, "one\n")
            expect(source.drain).to eq(["one"])
            # nothing new
            expect(source.drain).to be_empty
            append(file, "two\n")
            expect(source.drain).to eq(["two"])
          end
        end

        it "empty or missing file" do
          with_file do |_file, source|
            expect(source.drain).to be_empty
          end

          expect(TailSource.new("/no/such/trace.ndjson").drain).to be_empty
        end

        it "shrunk file resets" do
          with_file do |file, source|
            append(file, "x\ny\n")
            source.drain
            file.truncate(0)
            file.rewind
            append(file, "z\n")
            expect(source.drain).to eq(["z"])
          end
        end
      end
    end
  end
end
