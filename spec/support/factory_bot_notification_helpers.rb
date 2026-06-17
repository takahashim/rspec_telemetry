# frozen_string_literal: true

require "active_support/notifications"

# Emits the ActiveSupport::Notifications a real FactoryBot run would, so the
# subscriber specs can drive it without FactoryBot itself.
module FactoryBotNotificationHelpers
  def run_factory(name:, strategy: :create, traits: [], overrides: {}, factory: nil, &block)
    payload = {name: name, strategy: strategy, traits: traits, overrides: overrides, factory: factory}
    ActiveSupport::Notifications.instrument("factory_bot.before_run_factory", payload)
    ActiveSupport::Notifications.instrument("factory_bot.run_factory", payload) { block&.call }
  end
end
