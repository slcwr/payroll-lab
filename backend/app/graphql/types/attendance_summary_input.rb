module Types
  class AttendanceSummaryInput < BaseInputObject
    description "勤怠集計（分単位）"

    argument :employee_code, String
    argument :overtime_minutes, Int, required: false, default_value: 0
    argument :late_night_minutes, Int, required: false, default_value: 0
    argument :legal_holiday_minutes, Int, required: false, default_value: 0
    argument :absence_days, Int, required: false, default_value: 0
    argument :late_early_minutes, Int, required: false, default_value: 0
  end
end
