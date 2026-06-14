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
  spec.required_ruby_version = ">= 3.2"
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
  spec.add_dependency "tui_tui", "~> 0.1" # the interactive viewer's TUI framework

  # activesupport is optional at runtime: only FactoryBot tracking needs it
  # (via ActiveSupport::Notifications), and FactoryBot itself depends on it.
  spec.add_development_dependency "activesupport", ">= 6.0"
  spec.add_development_dependency "factory_bot", "~> 6.0"
end
