# frozen_string_literal: true

require "spec_helper"
require "active_support/isolated_execution_state"
require "active_support/notifications"

RSpec.describe "safety net" do
  describe "RSpecTelemetry.safely" do
    it "swallows any exception and returns nil" do
      result = nil
      expect do
        result = RSpecTelemetry.safely("test-ctx") { raise "boom" }
      end
        .to(output(/test-ctx.*RuntimeError: boom/).to_stderr)
      expect(result).to(be_nil)
    end

    it "even swallows non-StandardError exceptions" do
      expect do
        RSpecTelemetry.safely("test-ctx2") { raise Exception, "low-level" }
      end
        .to(output(/test-ctx2/).to_stderr)
    end

    it "warns only once per context" do
      expect do
        3.times { RSpecTelemetry.safely("dup") { raise "x" } }
        # 1回だけ
      end
        .to(output(/dup/).to_stderr)
    end

    it "returns the block value on success" do
      expect(RSpecTelemetry.safely("ok") { 42 }).to(eq(42))
    end
  end

  describe "FactoryBot subscriber" do
    # record が必ず例外を投げる壊れたrecorder
    let(:broken_recorder) do
      Class
        .new do
          def config = RSpecTelemetry::Config.new
          def record(*) = raise "recorder exploded"
        end
        .new
    end

    it "does not let a failing recorder break the instrumented factory call" do
      subscriber = RSpecTelemetry::Subscribers::FactoryBot.new(broken_recorder)
      subscriber.subscribe

      payload = {name: :user, strategy: :create, traits: [], overrides: {}, factory: nil}
      expect do
        # instrument のブロックの戻り値が保たれ、例外が伝播しないこと
        result = ActiveSupport::Notifications.instrument("factory_bot.run_factory", payload) { :ok }
        expect(result).to(eq(:ok))
      end
        .to(output(/factory_bot#finish.*recorder exploded/).to_stderr)
    ensure
      subscriber.unsubscribe
    end
  end
end
