# frozen_string_literal: true

# Builds factory_bot.run_factory event hashes for Summary specs.
module SummaryHelpers
  def factory_event(factory:, duration:, self_ms: nil, example_id: nil, strategy: "create")
    {
      type: "factory_bot.run_factory",
      factory: factory,
      strategy: strategy,
      duration_ms: duration,
      self_duration_ms: self_ms || duration,
      example_id: example_id
    }
  end
end
