# Changelog

## [Unreleased]

### Changed
- Both collection and the interactive viewer now require Ruby >= 3.2 (was >= 3.1
  for collection). `tui_tui`, needed only by the viewer, requires Ruby >= 3.2, so
  splitting the requirement gave no usable benefit while complicating install and
  CI.
- `tui_tui` is now a runtime dependency (was a development dependency) so the
  bundled `rspec-telemetry-viewer` executable works without a manual `gem
  "tui_tui"`. The viewer still degrades gracefully if it is unavailable.

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
