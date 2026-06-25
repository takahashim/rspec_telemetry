# rspec_telemetry

`rspec_telemetry` collects telemetry data during RSpec runs and writes it as NDJSON.
It helps you analyze your test suite.

- Duration for each example
- FactoryBot factory time, including nesting depth and self time
- Rankings of slow factories and slow examples
- Links between examples and factory events using `example_id`

## Requirements

- Ruby >= 3.2.
- RSpec.
- `tui_tui` powers the interactive viewer (`rspec-telemetry-viewer`).
- activesupport (optional): only needed for FactoryBot tracking, which relies on
  `ActiveSupport::Notifications`. FactoryBot pulls it in, so projects using
  FactoryBot already have it; otherwise factory tracking is skipped automatically.

## Install

```ruby
# Gemfile
group :test do
  gem "rspec_telemetry"
end
```

## Usage

```ruby
# spec/spec_helper.rb, etc.
require "rspec_telemetry"
```

It can be used together with normal human-readable output such as `progress`.

After requiring the gem, the following features are enabled:

- NDJSON output to `tmp/rspec_telemetry.ndjson`
- Recording of example start/finish events
- Recording of FactoryBot factory events
- Recording of suite finish events

If you want to specify the formatter explicitly in `.rspec`:

```text
--format progress
--format RSpecTelemetry::Formatter
```

> To disable automatic formatter registration, set the environment variable
> `RSPEC_TELEMETRY_NO_AUTOLOAD=1`.

## Configuration

```ruby
RSpecTelemetry.configure do |config|
  config.enabled = true
  config.output_path = "tmp/rspec_telemetry.ndjson"
  config.capture_examples = true
  config.capture_factory_bot = true
  config.print_summary = false        # true: print a summary to stderr at the end
  config.flush_each = false           # true: flush after each event, useful for tail -f
  config.slow_factory_threshold_ms = nil
  config.slow_example_threshold_ms = 1000.0
end
```

## Finding what is slow: `rspec-telemetry`

After running your tests, you can analyze the generated NDJSON file and see where time was spent.

```bash
$ bundle exec rspec
$ bundle exec rspec-telemetry          # automatically reads tmp/rspec_telemetry*.ndjson
```

```text
Overview
--------
  examples:              3 (0 failed, 0 pending)
  suite wall time:       91.6ms
  example time (sum):    89.8ms
  factory self time:     63.8ms (71.1% of example time)   <- 70% of test time was spent in factories

Slowest files (sum of example time)
Slowest examples
Slowest factories (by self time, excludes nested children)
  1. user:create   count 9   self 56.1ms   total 56.1ms   avg 6.2ms   max 6.7ms
```

Options:

```bash
rspec-telemetry --top 30                          # number of items shown in each section
rspec-telemetry --example "./spec/x_spec.rb[1:2]" # drill down into one example, including nested factories
rspec-telemetry tmp/rspec_telemetry.1.ndjson ...  # explicitly specify files, useful for parallel test runs
```

Example drill-down output:

```text
Example: ./spec/x_spec.rb[2:1]
  status: passed   duration: 52.4ms
  FactoryBot calls (indented by nesting depth):
     user:create  self 6.7ms / total 6.7ms
    order:create  self 2.6ms / total 9.3ms      <- order total includes child user time
  factory self total: 27.2ms across 6 calls
```

## Comparing factory usage between two runs

Use `rspec-telemetry-compare` to compare FactoryBot call counts and cumulative
factory time between two telemetry files.

```bash
$ bundle exec rspec-telemetry-compare \
    tmp/rspec_telemetry.before.ndjson \
    tmp/rspec_telemetry.after.ndjson
```

Factories are grouped by `factory:strategy`, so `user:create` and `user:build`
are compared separately. Use `--by-factory` to combine strategies and compare by
factory name only (e.g. one `user` row).

By default, only root factory events (`depth == 0`) are counted, and their
inclusive `duration_ms` is compared.

With `--all-depths`, every factory event is counted and `self_duration_ms` is
compared. Self time excludes nested child factories, so it avoids double
counting while showing the actual number and cost of associated factories.

```bash
rspec-telemetry-compare --sort count BEFORE AFTER
rspec-telemetry-compare --sort factory BEFORE AFTER
rspec-telemetry-compare --all-depths BEFORE AFTER
rspec-telemetry-compare --by-factory BEFORE AFTER     # combine create/build
rspec-telemetry-compare --all-depths --by-factory BEFORE AFTER
```

## TUI viewer: `rspec-telemetry-viewer`

You can view the same NDJSON file in an interactive terminal UI.

The viewer uses the built-in TUI implementation and only depends on `io-console`.

In a terminal, it shows a timeline, details, and a status bar.
When output is piped or redirected, it prints a text report instead.

```bash
$ bundle exec rspec-telemetry-viewer tmp/rspec_telemetry.ndjson           # TUI when running in a terminal
$ bundle exec rspec-telemetry-viewer --follow tmp/rspec_telemetry.ndjson  # follow a running test
$ bundle exec rspec-telemetry-viewer --plain  tmp/rspec_telemetry.ndjson  # force text report
```

Use `1`, `2`, and `3` to switch between the three screens:

- `1` Timeline: shows examples in execution order, with factory calls grouped under each example
- `2` Slowest examples: ranks examples by duration
- `3` Factories by self time: groups factories by `factory:strategy` and ranks them by self time

## Example output: NDJSON

```text
$ bundle exec rspec
```

```json
{"type":"example.started","example_id":"./spec/models/user_spec.rb[1:1]", ...}
{"type":"factory_bot.run_factory","example_id":"./spec/models/user_spec.rb[1:1]","factory":"user","strategy":"create","traits":["admin"],"overrides":["email"],"duration_ms":42.381,"self_duration_ms":30.12,"depth":0,"parent_factory":null}
{"type":"example.finished","example_id":"./spec/models/user_spec.rb[1:1]","status":"passed","duration_ms":71.552}
```

## Design notes

#### Override values are not recorded

For FactoryBot overrides, `rspec_telemetry` records only the attribute names.
It does not record the actual values, because they may contain personal information, secrets, or other sensitive data.

#### Nested factories and double counting

FactoryBot associations can create other factories internally.
This is why `rspec_telemetry` also records `self_duration_ms`.

Use self time when you want to find which factory is really slow.

#### Parallel test runs

When `TEST_ENV_NUMBER` is set, `rspec_telemetry` adds the worker number to the output file name.
This prevents multiple parallel workers from writing to the same NDJSON file.

#### Does not affect test results

Telemetry should not change the result of your test suite.

If writing telemetry data fails, `rspec_telemetry` ignores the error and prints only a warning.
It does not change whether examples pass or fail.
