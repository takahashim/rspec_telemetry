# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

module RSpecTelemetry
  module Trace
    module Viewer
      # Viewing the spec source behind a step: the bottom strip (and `S` pager)
      # show the test file at the example's line (file_path:line_number), and a
      # factory event borrows the source of the example that owns it.
      RSpec.describe App do
        SPEC = <<~RUBY
          RSpec.describe "Posts" do
            it "creates a post" do
              user = create(:user)
              expect(create(:post)).to be_persisted
            end
          end
        RUBY

        let(:size) { TuiTui::Size.new(rows: 16, cols: 70) }
        let(:ctx) { render_context(size) }

        context "with the spec file on disk" do
          around do |example|
            Dir.mktmpdir do |root|
              @root = root
              ::File.write(::File.join(root, "posts_spec.rb"), SPEC)
              example.run
            end
          end

          let(:app) do
            doc = Document.from_lines(
              [
                started(id: "a", file: "posts_spec.rb", line: 4, desc: "Posts creates a post"),
                factory(name: "post", ex: "a"),
                finished(id: "a", file: "posts_spec.rb", line: 4, status: "passed"),
                suite(examples: 1)
              ]
            )
            App.new(doc, depth: :ansi256, source_root: @root)
          end

          it "persistent source pane shows the selected step" do
            shown = screen(app)
            expect(shown).to include("source: posts_spec.rb:4")
            # the source code is shown
            expect(shown).to include("be_persisted")
            # the triggering line is marked
            expect(shown).to include("→")
          end

          it "s toggles the source pane" do
            expect(screen(app)).to include("source: posts_spec.rb:4")
            app.update(key("s"))
            expect(screen(app)).not_to include("source: posts_spec.rb:4")
            app.update(key("s"))
            expect(screen(app)).to include("source: posts_spec.rb:4")
          end

          it "event uses the owning example source" do
            # move onto the factory event under the example
            app.update(key("j"))
            expect(screen(app)).to include("source: posts_spec.rb:4")
          end

          it "capital s toggles the full screen pager" do
            expect(screen(app)).not_to include("+--")
            app.update(key("S"))
            expect(screen(app)).to include("+--")
            app.update(key("S"))
            expect(screen(app)).not_to include("+--")
          end
        end

        it "persistent source pane updates when moving to another step" do
          spec = "describe\n  visit\n  click\n"
          Dir.mktmpdir do |root|
            ::File.write(::File.join(root, "s_spec.rb"), spec)
            doc = Document.from_lines(
              [
                started(id: "a", file: "s_spec.rb", line: 1, desc: "first"),
                finished(id: "a", file: "s_spec.rb", line: 1),
                started(id: "b", file: "s_spec.rb", line: 3, desc: "second"),
                finished(id: "b", file: "s_spec.rb", line: 3),
                suite(examples: 2)
              ]
            )
            a = App.new(doc, depth: :ansi256, source_root: root)
            expect(screen(a)).to include("source: s_spec.rb:1")
            # move to the second example
            a.update(key("j"))
            expect(screen(a)).to include("source: s_spec.rb:3")
          end
        end

        it "no source pane when no step has source" do
          doc = Document.from_lines([started(id: "a", file: nil, desc: "x"), finished(id: "a", file: nil), suite])
          a = App.new(doc, depth: :ansi256)
          expect(screen(a)).not_to include("source:")
        end

        it "resolves source from the trace files ancestors" do
          # A real layout: trace at <root>/tmp/run.ndjson, spec at <root>/spec.
          # No --source-root is given (source_root points elsewhere), yet the spec
          # is found by walking up from the trace file's directory.
          Dir.mktmpdir do |root|
            ::FileUtils.mkdir_p(::File.join(root, "tmp"))
            ::FileUtils.mkdir_p(::File.join(root, "spec"))
            ::File.write(::File.join(root, "spec", "foo_spec.rb"), "describe\n  it\n  create\n")
            doc = Document.from_lines(
              [
                started(id: "a", file: "./spec/foo_spec.rb", line: 2, desc: "Foo"),
                finished(id: "a", file: "./spec/foo_spec.rb", line: 2),
                suite(examples: 1)
              ]
            )
            a = App.new(doc, depth: :ansi256, base_dir: ::File.join(root, "tmp"), source_root: "/nonexistent")
            expect(screen(a)).to include("source: ./spec/foo_spec.rb:2")
            expect(screen(a)).not_to include("source not found")
          end
        end

        it "missing source file is reported not crashed" do
          doc = Document.from_lines(
            [
              started(id: "a", file: "nope_spec.rb", line: 9, desc: "x"),
              finished(id: "a", file: "nope_spec.rb", line: 9),
              suite
            ]
          )
          a = App.new(doc, depth: :ansi256, source_root: "/nonexistent")
          expect(screen(a)).to include("source not found")
        end
      end
    end
  end
end
