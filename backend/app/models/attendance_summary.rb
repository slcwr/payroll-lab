class AttendanceSummary < ApplicationRecord
  YEAR_MONTH_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

  belongs_to :employee

  validates :year_month, format: { with: YEAR_MONTH_FORMAT }, uniqueness: { scope: :employee_id }
  validates :overtime_minutes, :late_night_minutes, :legal_holiday_minutes, :absence_days, :late_early_minutes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def to_payroll_summary
    Payroll::AttendanceSummary.new(
      overtime_minutes: overtime_minutes, late_night_minutes: late_night_minutes,
      legal_holiday_minutes: legal_holiday_minutes, absence_days: absence_days,
      late_early_minutes: late_early_minutes
    )
  end
end
