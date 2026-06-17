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
        around do |example|
          Tempfile.create(["trace", ".ndjson"]) do |file|
            file.sync = true
            @file = file
            example.run
          end
        end

        let(:source) { TailSource.new(@file.path) }

        it "returns complete lines" do
          @file.write("a\nb\n")
          expect(source.drain).to eq(%w[a b])
        end

        it "holds back partial trailing line" do
          @file.write("a\nb")
          # "b" has no newline yet
          expect(source.drain).to eq(["a"])
          @file.write("c\n")
          # completed on the next drain
          expect(source.drain).to eq(["bc"])
        end

        it "drain is incremental" do
          @file.write("one\n")
          expect(source.drain).to eq(["one"])
          # nothing new
          expect(source.drain).to be_empty
          @file.write("two\n")
          expect(source.drain).to eq(["two"])
        end

        it "empty or missing file" do
          expect(source.drain).to be_empty
          expect(TailSource.new("/no/such/trace.ndjson").drain).to be_empty
        end

        it "shrunk file resets" do
          @file.write("x\ny\n")
          source.drain
          @file.truncate(0)
          @file.rewind
          @file.write("z\n")
          expect(source.drain).to eq(["z"])
        end
      end
    end
  end
end
