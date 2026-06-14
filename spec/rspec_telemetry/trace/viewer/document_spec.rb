# frozen_string_literal: true

require "spec_helper"

module RSpecTelemetry
  module Trace
    module Viewer
      # Folding raw rspec_telemetry NDJSON into ordered entries: examples become
      # grouping Actions, factory calls become Events under them, and the tolerance
      # rules (blank / broken / unknown / typeless lines).
      RSpec.describe Document do
        include Fixtures

        # An admin example with one factory, then a failing example whose order
        # factory nests a user factory.
        def lines
          [
            started(id: "a", file: "spec/user_spec.rb", line: 3, desc: "User admin", mono: 1000.0),
            factory(name: "user", ex: "a", traits: ["admin"], dur: 5.0, mono: 1000.001),
            finished(id: "a", status: "passed", dur: 5.0, file: "spec/user_spec.rb", line: 3, mono: 1000.006),
            started(id: "b", file: "spec/user_spec.rb", line: 9, desc: "User order", mono: 1000.01),
            factory(name: "user", ex: "b", depth: 1, parent: "order", dur: 4.0, mono: 1000.02),
            factory(name: "order", ex: "b", depth: 0, dur: 7.0, self_ms: 3.0, mono: 1000.021),
            finished(
              id: "b",
              status: "failed",
              dur: 9.0,
              exc: ["RSpec::Expectations::ExpectationNotMetError", "boom"],
              file: "spec/user_spec.rb",
              line: 9,
              mono: 1000.03
            ),
            suite(examples: 2, failures: 1, mono: 1000.035)
          ]
        end

        def document = Document.from_lines(lines)

        it "examples become actions factories become events" do
          kinds = document.entries.map { |e| e.is_a?(Document::Action) ? "example" : e.op }
          expect(kinds).to eq(%w[example factory example factory factory])
        end

        it "example started carries label and source" do
          action = document.actions.first
          expect(action.label).to eq("User admin")
          expect(action.source).to eq("spec/user_spec.rb:3")
        end

        it "factory events belong to their example" do
          events = document.events
          # user -> example a
          expect(events[0].action).to eq(document.actions[0].seq)
          # nested user -> example b
          expect(events[1].action).to eq(document.actions[1].seq)
          # order -> example b
          expect(events[2].action).to eq(document.actions[1].seq)
        end

        it "example finished folds status and duration into the action" do
          a, b = document.actions
          expect(a.status).to eq("passed")
          expect(a.duration_ms).to be_within(0.001).of(5.0)
          expect(b.status).to eq("failed")
          expect(b.exception["class"]).to eq("RSpec::Expectations::ExpectationNotMetError")
          expect(b.exception["message"]).to eq("boom")
        end

        it "suite status and counts" do
          doc = document
          expect(doc.status).to eq("failed")
          expect(doc.example_count).to eq(2)
          expect(doc.failure_count).to eq(1)
          expect(doc.failed_action).to eq(document.actions[1].seq)
          expect(doc.pending?).to be_falsey
        end

        it "wall ms is relative to the first event" do
          # mono 1000.0 -> 0ms; the order factory at 1000.021 -> 21ms.
          expect(document.actions.first.wall_ms).to be_within(0.001).of(0.0)
          order = document.events.find { |e| e.fields["factory"] == "order" }
          expect(order.fields["wall_ms"]).to be_within(0.001).of(21.0)
        end

        it "pending until suite finished" do
          doc = Document.from_lines(lines.first(2))
          expect(doc.pending?).to be_truthy
          expect(doc.status).to eq("pending")
        end

        it "passing suite is ok" do
          doc = Document.from_lines([started(id: "a"), finished(id: "a"), suite(examples: 1, failures: 0)])
          expect(doc.status).to eq("ok")
        end

        it "skips blank and broken lines" do
          doc = Document.from_lines(
            [
              "",
              "   ",
              started(id: "a"),
              # truncated final line (crash)
              "{\"type\":\"factory_bot.run_fac"
            ]
          )
          expect(doc.entries.size).to eq(1)
        end

        it "keeps unknown types as generic events" do
          doc = Document.from_lines(
            ["{\"type\":\"sql.active_record\",\"example_id\":null,\"name\":\"User Load\",\"duration_ms\":3.4}"]
          )
          event = doc.events.first
          expect(event.op).to eq("sql.active_record")
          expect(event.fields["duration_ms"]).to eq(3.4)
        end

        it "ignores lines without type" do
          doc = Document.from_lines(["{\"note\":\"no type here\"}"])
          expect(doc.entries).to be_empty
        end
      end
    end
  end
end
