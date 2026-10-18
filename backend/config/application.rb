require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module PayrollLab
  class Application < Rails::Application
    config.load_defaults 8.0

    # lib/payroll は Rails に依存しないドメイン層。
    # Zeitwerk の命名規約（1ファイル1定数）に縛られないよう自動読み込みから外し、
    # config/initializers/payroll.rb で明示的に読み込む。
    config.autoload_lib(ignore: %w[assets tasks payroll payroll.rb])

    config.api_only = true
    config.time_zone = "Tokyo"
    config.active_record.default_timezone = :utc

    # 開発環境ではプロセス内で非同期実行。本番は Cloud Run Jobs に計算を任せる（PayrollRuns::Dispatcher）。
    config.active_job.queue_adapter = :async

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
