# Changelog

## [0.2.0] - 2026-06-17

### Changed
- Collection (the RSpec formatter that writes NDJSON) now runs on Ruby >= 3.1.
- `tui_tui` is no longer a runtime dependency; it is only needed for the
  interactive viewer (Ruby >= 3.2, `gem "tui_tui"`). The viewer degrades with a
  clear message when it is missing.

### Added
- Viewer renders Unicode box-drawing chrome (frames, dividers, scrollbar) when
  the terminal supports it, falling back to ASCII otherwise.

### Fixed
- FactoryBot timing is captured again on Rails 6.x / ActiveSupport 6 (a
  Rails 7-only `require` had silently disabled the subscription).

## [0.1.0] - 2026-06-17

First public release.

[Unreleased]: https://github.com/takahashim/rspec_telemetry/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/takahashim/rspec_telemetry/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/takahashim/rspec_telemetry/releases/tag/v0.1.0
