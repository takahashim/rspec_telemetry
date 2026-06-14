# frozen_string_literal: true

require "spec_helper"
require "active_support/notifications"
require "rspec_telemetry/subscribers/factory_bot"

RSpec.describe RSpecTelemetry::Subscribers::FactoryBot do
  # 記録されたイベントを捕まえるだけのフェイクrecorder
  let(:recorder) do
    Class
      .new do
        attr_reader(:events)

        def initialize
          @events = []
          @config = RSpecTelemetry::Config.new
        end

        attr_reader(:config)

        def record(type, fields = {})
          @events << fields.merge(type: type)
        end
      end
      .new
  end

  subject(:subscriber) { described_class.new(recorder) }

  before { subscriber.subscribe }
  after { subscriber.unsubscribe }

  # FactoryBotの実payload(name/strategy/traits/overrides/factory)を模したinstrument
  def run_factory(name:, strategy: :create, traits: [], overrides: {}, factory: nil)
    payload = {name: name, strategy: strategy, traits: traits, overrides: overrides, factory: factory}
    ActiveSupport::Notifications.instrument("factory_bot.before_run_factory", payload)
    ActiveSupport::Notifications.instrument("factory_bot.run_factory", payload) { yield if block_given? }
  end

  it "records only override attribute NAMES, never values (privacy)" do
    run_factory(name: :user, overrides: {email: "secret@example.com", password: "hunter2"})

    event = recorder.events.last
    expect(event[:overrides]).to(contain_exactly("email", "password"))
    expect(event.to_s).not_to(include("secret@example.com"))
    expect(event.to_s).not_to(include("hunter2"))
  end

  it "stringifies factory, strategy and traits" do
    run_factory(name: :admin_user, strategy: :build, traits: %i[admin verified])

    event = recorder.events.last
    expect(event).to(include(factory: "admin_user", strategy: "build", traits: %w[admin verified]))
  end

  it "derives factory_class from payload[:factory].build_class" do
    factory = double("Factory", build_class: String)
    run_factory(name: :user, factory: factory)
    expect(recorder.events.last[:factory_class]).to(eq("String"))
  end

  it "computes depth, parent_factory and self_duration_ms for nested factories" do
    run_factory(name: :order) do
      run_factory(name: :user) { sleep(0.01) }
    end

    user = recorder.events.find { |e| e[:factory] == "user" }
    order = recorder.events.find { |e| e[:factory] == "order" }

    expect(user[:depth]).to(eq(1))
    expect(user[:parent_factory]).to(eq("order"))
    expect(order[:depth]).to(eq(0))
    expect(order[:parent_factory]).to(be_nil)

    # order の self は子(user)の時間を除いた値で、total より小さい
    expect(order[:self_duration_ms]).to(be < order[:duration_ms])
    expect(order[:self_duration_ms]).to(be >= 0)
    # user は子を持たないので self == total
    expect(user[:self_duration_ms]).to(be_within(0.001).of(user[:duration_ms]))
  end
end
