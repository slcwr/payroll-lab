# frozen_string_literal: true

module Payroll
  # 計算の入力となる値オブジェクト群。
  # ActiveRecord のモデルをそのまま渡さず、計算に必要な値だけを詰め替えて渡す（スナップショット）。
  # これにより「計算時点の値」が明確になり、計算処理は DB アクセスを一切しない。

  # 会社（事業所）ごとの就業規則・保険の設定
  WorkRules = Data.define(
    :prefecture,                    # 協会けんぽの支部（事業所所在地）: "tokyo" など
    :employment_insurance_business, # 雇用保険の事業区分: :general / :agriculture / :construction
    :social_insurance_collection,   # 社会保険料の徴収月: :next_month（翌月徴収）/ :current_month（当月徴収）
    :monthly_scheduled_hours,       # 月平均所定労働時間（割増賃金の時間単価の分母）
    :monthly_scheduled_days         # 月平均所定労働日数（欠勤控除の分母）
  ) do
    def initialize(prefecture:, employment_insurance_business: :general, social_insurance_collection: :next_month,
                   monthly_scheduled_hours:, monthly_scheduled_days:)
      super(
        prefecture: prefecture.to_s,
        employment_insurance_business: employment_insurance_business.to_sym,
        social_insurance_collection: social_insurance_collection.to_sym,
        monthly_scheduled_hours: BigDecimal(monthly_scheduled_hours.to_s),
        monthly_scheduled_days: BigDecimal(monthly_scheduled_days.to_s)
      )
    end
  end

  # 固定的な手当（役職手当・住宅手当など）
  Allowance = Data.define(:code, :name, :amount, :taxable, :overtime_base) do
    def initialize(code:, name:, amount:, taxable: true, overtime_base: true)
      super
    end
  end

  # 労務管理（従業員DB）から取り込む従業員情報。「データ入力レス」の入力側。
  EmployeeSnapshot = Data.define(
    :id, :code, :name, :birth_date, :hired_on, :retired_on,
    :base_salary,                    # 基本給（月給）
    :standard_monthly_remuneration,  # 標準報酬月額（算定基礎・月変で決定済みの値）
    :commute_allowance,              # 通勤手当（月額）
    :allowances,                     # Array<Allowance>
    :withholding_spouse,             # 源泉控除対象配偶者の有無
    :dependents_count,               # 源泉控除対象の扶養親族の数
    :resident_tax_monthly,           # 住民税（特別徴収）の月額
    :social_insurance_enrolled,      # 健康保険・厚生年金の加入
    :employment_insurance_enrolled   # 雇用保険の加入
  ) do
    def initialize(id:, code:, name:, birth_date:, hired_on:, base_salary:, retired_on: nil,
                   standard_monthly_remuneration: nil, commute_allowance: 0, allowances: [],
                   withholding_spouse: false, dependents_count: 0, resident_tax_monthly: 0,
                   social_insurance_enrolled: true, employment_insurance_enrolled: true)
      super
    end
  end

  # 勤怠集計（勤怠管理から取り込む月次の集計値）。分単位で受け取る。
  AttendanceSummary = Data.define(
    :overtime_minutes,       # 法定時間外労働
    :late_night_minutes,     # 深夜労働（22時〜5時）
    :legal_holiday_minutes,  # 法定休日労働
    :absence_days,           # 欠勤日数
    :late_early_minutes      # 遅刻・早退
  ) do
    def initialize(overtime_minutes: 0, late_night_minutes: 0, legal_holiday_minutes: 0, absence_days: 0, late_early_minutes: 0)
      super
    end

    def self.empty = new
  end

  # 給与計算の対象期間。ここでは「当月1日〜末日締め・翌月払い」などを表す。
  Period = Data.define(:year, :month, :payment_date) do
    def self.of(year_month, payment_date:)
      y, m = year_month.split("-").map(&:to_i)
      new(year: y, month: m, payment_date: payment_date.is_a?(Date) ? payment_date : Date.parse(payment_date.to_s))
    end

    def start_date = Date.new(year, month, 1)
    def end_date = Date.new(year, month, -1)
    alias_method :closing_date, :end_date
    def days = end_date.day
    def range = start_date..end_date
    def year_month = format("%04d-%02d", year, month)
    def previous_month_start = start_date.prev_month
  end
end
