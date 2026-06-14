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
        include Fixtures

        SPEC = <<~RUBY
          RSpec.describe "Posts" do
            it "creates a post" do
              user = create(:user)
              expect(create(:post)).to be_persisted
            end
          end
        RUBY

        def key(k) = TuiTui::KeyEvent.new(key: k)
        def size = TuiTui::Size.new(rows: 16, cols: 70)

        def with_app
          Dir.mktmpdir do |root|
            ::File.write(::File.join(root, "posts_spec.rb"), SPEC)
            doc = Document.from_lines(
              [
                started(id: "a", file: "posts_spec.rb", line: 4, desc: "Posts creates a post"),
                factory(name: "post", ex: "a"),
                finished(id: "a", file: "posts_spec.rb", line: 4, status: "passed"),
                suite(examples: 1)
              ]
            )
            yield App.new(doc, depth: :ansi256, source_root: root)
          end
        end

        def screen(a)
          (1..size.rows).map { |r| a.view(size).render_row(r, enabled: false) }.join("\n")
        end

        it "persistent source pane shows the selected step" do
          with_app do |a|
            shown = screen(a)
            expect(shown).to include("source: posts_spec.rb:4")
            # the source code is shown
            expect(shown).to include("be_persisted")
            # the triggering line is marked
            expect(shown).to include("→")
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

        it "s toggles the source pane" do
          with_app do |a|
            expect(screen(a)).to include("source: posts_spec.rb:4")
            a.update(key("s"))
            expect(screen(a)).not_to include("source: posts_spec.rb:4")
            a.update(key("s"))
            expect(screen(a)).to include("source: posts_spec.rb:4")
          end
        end

        it "event uses the owning example source" do
          with_app do |a|
            # move onto the factory event under the example
            a.update(key("j"))
            expect(screen(a)).to include("source: posts_spec.rb:4")
          end
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

        it "capital s toggles the full screen pager" do
          with_app do |a|
            expect(screen(a)).not_to include("+--")
            a.update(key("S"))
            expect(screen(a)).to include("+--")
            a.update(key("S"))
            expect(screen(a)).not_to include("+--")
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
