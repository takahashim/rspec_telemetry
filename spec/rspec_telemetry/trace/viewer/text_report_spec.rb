# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # The decorated text frontend. With color disabled the output is plain and
      # deterministic, so it can be asserted exactly (golden).
      RSpec.describe TextReport do
        include Fixtures

        def lines
          [
            started(id: "a", file: "spec/user_spec.rb", line: 3, desc: "User admin"),
            factory(name: "user", ex: "a", traits: ["admin"], overrides: ["email"], dur: 5.0),
            finished(id: "a", file: "spec/user_spec.rb", line: 3, status: "passed", dur: 5.0),
            started(id: "b", file: "spec/user_spec.rb", line: 9, desc: "User order"),
            factory(name: "user", ex: "b", depth: 1, parent: "order", dur: 4.0),
            factory(name: "order", ex: "b", depth: 0, dur: 7.0, self_ms: 3.0),
            finished(
              id: "b",
              file: "spec/user_spec.rb",
              line: 9,
              status: "failed",
              dur: 9.0,
              exc: ["RSpec::ExpectationNotMet", "boom"]
            ),
            suite(examples: 2, failures: 1)
          ]
        end

        def plain_report = TextReport.new(Document.from_lines(lines), enabled: false)

        it "plain render is example grouped with source location" do
          expected = <<~TEXT
            EXAMPLE User admin  at: spec/user_spec.rb:3
              FACTORY user:create [admin]  5ms
            EXAMPLE User order [FAILED]  at: spec/user_spec.rb:9
                FACTORY user:create  4ms
              FACTORY order:create  7ms (self 3ms)
          TEXT
            .chomp
          expect(plain_report.render).to eq(expected)
        end

        it "summary counts events and status" do
          # Events only (examples are not counted): three factory calls.
          expect(plain_report.summary).to eq("3 events  failed")
        end

        it "unknown type renders generically" do
          doc = Document.from_lines(["{\"type\":\"sql.active_record\",\"name\":\"User Load\",\"duration_ms\":3.4}"])
          report = TextReport.new(doc, enabled: false)
          expect(report.render).to eq("  SQL.ACTIVE_RECORD {\"name\" => \"User Load\", \"duration_ms\" => 3.4}")
        end

        it "color is emitted for a failed example" do
          doc = Document.from_lines([started(id: "a", desc: "boom"), finished(id: "a", status: "failed")])
          report = TextReport.new(doc, depth: :ansi256, enabled: true)
          # bold red failed example line
          expect(report.render).to include("\e[1;31m")
        end
      end
    end
  end
end
