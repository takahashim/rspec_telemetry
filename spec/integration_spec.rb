# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"
require "json"

# 実際に `rspec` をサブプロセスで起動し、FactoryBotと連携したNDJSON出力を検証する
# エンドツーエンドのテスト。
RSpec.describe "end-to-end rspec run" do
  GEM_LIB = File.expand_path("../lib", __dir__)

  FIXTURE_SPEC = <<~RUBY
    require "factory_bot"
    require "rspec_telemetry" # autoloadでformatterが登録される

    class User
      attr_accessor :email, :name
      def save!; end
    end

    class Order
      attr_accessor :user
      def save!; end
    end

    FactoryBot.define do
      factory :user do
        email { "default@example.com" }
        trait(:admin) { name { "admin" } }
      end

      factory :order do
        user # association -> ネストした run_factory
      end
    end

    RSpec.configure do |c|
      c.include FactoryBot::Syntax::Methods
    end

    RSpec.describe "telemetry sample" do
      it "creates a user with secret override" do
        create(:user, :admin, email: "secret@example.com")
      end

      it "creates an order with a nested user" do
        create(:order)
      end
    end
  RUBY

  it "produces an NDJSON file with example and factory events" do
    Dir.mktmpdir do |dir|
      spec_path = File.join(dir, "sample_spec.rb")
      File.write(spec_path, FIXTURE_SPEC)

      # 親プロセス(gem自身のテスト)が設定した自動登録抑止を、サブプロセスでは解除する
      env = {"RUBYOPT" => "-I#{GEM_LIB}", "RSPEC_TELEMETRY_NO_AUTOLOAD" => nil}
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, "-S", "rspec", "--no-color", spec_path, chdir: dir)

      ndjson = File.join(dir, "tmp", "rspec_telemetry.ndjson")
      aggregate_failures do
        expect(status).to(be_success, "rspec failed:\n#{stdout}\n#{stderr}")
        expect(File).to(exist(ndjson))

        events = File.readlines(ndjson, chomp: true).map { |l| JSON.parse(l) }
        types = events.map { |e| e["type"] }

        # 必須イベントが揃う
        expect(types).to(
          include(
            "example.started",
            "example.finished",
            "factory_bot.run_factory",
            "suite.finished"
          )
        )

        # 共通フィールド
        events.each do |e|
          expect(e).to(include("type", "timestamp", "monotonic_time", "pid", "thread_id"))
          expect(e["timestamp"]).to(end_with("Z"))
        end

        # factoryイベントにexample_idが紐づく
        factories = events.select { |e| e["type"] == "factory_bot.run_factory" }
        expect(factories).not_to(be_empty)
        expect(factories).to(all(include("example_id" => a_string_matching(/sample_spec\.rb/))))

        # override値は記録されず、属性名のみ
        user_create = factories.find { |e| e["factory"] == "user" && e["traits"].include?("admin") }
        expect(user_create["overrides"]).to(include("email"))
        expect(user_create["traits"]).to(include("admin"))
        expect(File.read(ndjson)).not_to(include("secret@example.com"))

        # ネスト: order(depth 0) の中で user(depth 1, parent=order) が作られる
        order = factories.find { |e| e["factory"] == "order" }
        nested_user = factories.find { |e| e["factory"] == "user" && e["depth"] == 1 }
        expect(order["depth"]).to(eq(0))
        expect(nested_user["parent_factory"]).to(eq("order"))
        expect(order["self_duration_ms"]).to(be <= order["duration_ms"])

        # suite統計
        suite = events.find { |e| e["type"] == "suite.finished" }
        expect(suite["example_count"]).to(eq(2))
        expect(suite["failure_count"]).to(eq(0))
      end
    end
  end
end
