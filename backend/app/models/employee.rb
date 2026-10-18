class Employee < ApplicationRecord
  belongs_to :company
  has_many :employee_allowances, dependent: :delete_all
  has_many :attendance_summaries, dependent: :delete_all
  has_many :payslips, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: { scope: :company_id }
  validates :name, :birth_date, :hired_on, presence: true
  validates :base_salary, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :retired_after_hired

  # 期間中に1日でも在籍している従業員
  scope :active_during, lambda { |from, to|
    where(hired_on: ..to).where("employees.retired_on IS NULL OR employees.retired_on >= ?", from)
  }

  # 計算時点の値をドメイン層の値オブジェクトに詰め替える。
  # employee_allowances と pay_item は呼び出し側で includes 済みであること（N+1 防止）。
  def to_payroll_snapshot
    Payroll::EmployeeSnapshot.new(
      id: id, code: code, name: name, birth_date: birth_date, hired_on: hired_on, retired_on: retired_on,
      base_salary: base_salary, standard_monthly_remuneration: standard_monthly_remuneration,
      commute_allowance: commute_allowance,
      allowances: employee_allowances.sort_by { _1.pay_item.position }.map(&:to_payroll_allowance),
      withholding_spouse: withholding_spouse, dependents_count: dependents_count,
      resident_tax_monthly: resident_tax_monthly,
      social_insurance_enrolled: social_insurance_enrolled,
      employment_insurance_enrolled: employment_insurance_enrolled
    )
  end

  private

  def retired_after_hired
    return if retired_on.blank? || hired_on.blank?

    errors.add(:retired_on, "は入社日以降の日付にしてください") if retired_on < hired_on
  end
end
