require "net/http"

module PayrollRuns
  # 給与計算の実行方法を切り替える。
  #
  # - development / test: ActiveJob（プロセス内）で実行
  # - production: Cloud Run Jobs を起動し、複数タスクで並列計算する
  #   API サーバー（Cloud Run サービス）はリクエストを受けたらすぐ返し、
  #   重い計算はスケールや実行時間の制約が異なるジョブ側に任せる。
  class Dispatcher
    def self.call(run)
      shards = ENV.fetch("PAYROLL_SHARD_COUNT", 1).to_i.clamp(1, 100)
      run.start_calculation!(shard_count: shards)

      case ENV.fetch("PAYROLL_DISPATCHER", "active_job")
      when "cloud_run_job" then CloudRunJob.new.run(run, shards)
      else CalculatePayrollRunJob.perform_later(run.id)
      end
    end

    # Cloud Run Admin API（v2）でジョブを実行する。
    # 認証は実行環境のサービスアカウント（メタデータサーバーのトークン）を使い、鍵ファイルを持たない。
    class CloudRunJob
      METADATA_TOKEN_URL = URI("http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token")

      def run(payroll_run, shards)
        uri = URI("https://run.googleapis.com/v2/projects/#{ENV.fetch('GOOGLE_CLOUD_PROJECT')}/locations/" \
                  "#{ENV.fetch('CLOUD_RUN_REGION')}/jobs/#{ENV.fetch('PAYROLL_JOB_NAME')}:run")
        body = {
          overrides: {
            taskCount: shards,
            containerOverrides: [{ args: ["./bin/rails", "payroll:calculate[#{payroll_run.id}]"] }]
          }
        }
        res = Net::HTTP.post(uri, body.to_json, "Content-Type" => "application/json", "Authorization" => "Bearer #{token}")
        raise "Cloud Run Job の起動に失敗しました: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
      rescue StandardError => e
        payroll_run.fail!(e)
        raise
      end

      private

      def token
        req = Net::HTTP::Get.new(METADATA_TOKEN_URL, "Metadata-Flavor" => "Google")
        res = Net::HTTP.start(METADATA_TOKEN_URL.host, METADATA_TOKEN_URL.port) { _1.request(req) }
        JSON.parse(res.body).fetch("access_token")
      end
    end
  end
end
