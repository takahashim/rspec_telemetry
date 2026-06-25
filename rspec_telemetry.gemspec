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
  spec.executables = ["rspec-telemetry", "rspec-telemetry-compare", "rspec-telemetry-viewer"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec-core", ">= 3.0"
  spec.add_dependency "tui_tui", "~> 0.2"
end
