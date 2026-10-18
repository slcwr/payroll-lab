class Company < ApplicationRecord
  # 明細が従業員を参照しているため、給与計算 → 従業員 → 給与項目の順に削除する
  has_many :payroll_runs, dependent: :delete_all
  has_many :employees, dependent: :delete_all
  has_many :pay_items, dependent: :delete_all

  validates :name, presence: true
  validates :prefecture, presence: true
  validates :employment_insurance_business, inclusion: { in: %w[general agriculture construction] }
  validates :social_insurance_collection, inclusion: { in: %w[next_month current_month] }
  validates :monthly_scheduled_hours, :monthly_scheduled_days, numericality: { greater_than: 0 }

  # ドメイン層へ渡す設定値（ActiveRecord をそのまま渡さない）
  def work_rules
    Payroll::WorkRules.new(
      prefecture: prefecture,
      employment_insurance_business: employment_insurance_business,
      social_insurance_collection: social_insurance_collection,
      monthly_scheduled_hours: monthly_scheduled_hours,
      monthly_scheduled_days: monthly_scheduled_days
    )
  end
end
