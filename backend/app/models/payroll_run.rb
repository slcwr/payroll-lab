# 月次の給与計算の実行単位（会社 × 対象月）。
#
#   draft ──calculate──▶ calculating ──(全タスク完了)──▶ calculated ──confirm──▶ confirmed
#     ▲                       │                              │
#     └──────── failed ◀──────┘          再計算 ◀────────────┘
#
# confirmed になった計算結果は変更できない（明細配付・振込データの元になるため）。
class PayrollRun < ApplicationRecord
  class InvalidTransition < StandardError; end

  belongs_to :company
  has_many :payslips, dependent: :delete_all

  enum :status, {
    draft: "draft", calculating: "calculating", calculated: "calculated", confirmed: "confirmed", failed: "failed"
  }, validate: true

  validates :year_month, format: { with: AttendanceSummary::YEAR_MONTH_FORMAT }, uniqueness: { scope: :company_id }
  validates :payment_date, presence: true
  validate :payment_date_after_period, if: -> { payment_date.present? && year_month.present? }

  def period
    Payroll::Period.of(year_month, payment_date: payment_date)
  end

  def start_calculation!(shard_count: 1)
    with_lock do
      raise InvalidTransition, "確定済みの給与計算は再計算できません" if confirmed?
      raise InvalidTransition, "計算中です" if calculating?

      update!(status: :calculating, shard_count: shard_count, completed_shards: 0,
              started_at: Time.current, calculated_at: nil, error_message: nil)
    end
  end

  # 並列タスクの1つが終わるたびに呼ばれる。最後のタスクが集計を行う。
  def shard_completed!
    with_lock do
      increment!(:completed_shards)
      finish! if completed_shards >= shard_count
    end
  end

  def confirm!
    with_lock do
      raise InvalidTransition, "計算が完了していません" unless calculated?

      update!(status: :confirmed, confirmed_at: Time.current)
    end
  end

  def fail!(error)
    update_columns(status: "failed", error_message: "#{error.class}: #{error.message}".truncate(2000), updated_at: Time.current)
  end

  # 計算結果の目印（入社者・退職者・差引マイナスなど）ごとの件数
  def flag_counts
    Payslip.from(payslips.select("unnest(payslips.flags) AS flag"), :t).group("t.flag").count
  end

  private

  def finish!
    totals = payslips.pluck(
      Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(gross_pay), 0)"),
      Arel.sql("COALESCE(SUM(total_deductions), 0)"), Arel.sql("COALESCE(SUM(net_pay), 0)")
    ).first
    update!(status: :calculated, calculated_at: Time.current, employees_count: totals[0],
            gross_total: totals[1], deductions_total: totals[2], net_total: totals[3])
  end

  def payment_date_after_period
    return unless year_month.match?(AttendanceSummary::YEAR_MONTH_FORMAT)

    errors.add(:payment_date, "は対象月の初日以降にしてください") if payment_date < period.start_date
  end
end
