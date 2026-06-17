# frozen_string_literal: true

require_relative "lib/rspec_telemetry/version"

Gem::Specification.new do |spec|
  spec.name = "rspec_telemetry"
  spec.version = RSpecTelemetry::VERSION
  spec.authors = ["takahashimm"]
  spec.email = ["takahashimm@gmail.com"]

  spec.summary = "Collect RSpec / FactoryBot telemetry as NDJSON to find slow tests."
  spec.description = "Collect RSpec / FactoryBot telemetry as NDJSON to find slow tests."
  spec.homepage = "https://github.com/takahashim/rspec_telemetry"
  spec.license = "MIT"
  # Collection (the RSpec formatter -> NDJSON) runs on Ruby >= 3.1. The
  # interactive viewer needs >= 3.2 and the optional tui_tui gem; it degrades
  # gracefully when either is missing.
  spec.required_ruby_version = ">= 3.1"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/takahashim/rspec_telemetry"

  spec.files = Dir["lib/**/*.rb", "exe/*", "examples/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.bindir = "exe"
  # rspec-telemetry: static text report over the NDJSON.
  # rspec-telemetry-viewer: interactive TUI viewer over the NDJSON.
  spec.executables = ["rspec-telemetry", "rspec-telemetry-viewer"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec-core", ">= 3.0"

  # tui_tui is optional at runtime: only the interactive viewer needs it (Ruby
  # >= 3.2). Keeping it out of the runtime deps lets the collector install and
  # run on Ruby 3.1. Add `gem "tui_tui"` yourself to use the viewer.
  spec.add_development_dependency "tui_tui", "~> 0.2"

  # activesupport is optional at runtime: only FactoryBot tracking needs it
  # (via ActiveSupport::Notifications), and FactoryBot itself depends on it.
  spec.add_development_dependency "activesupport", ">= 6.0"
  spec.add_development_dependency "factory_bot", "~> 6.0"
end
