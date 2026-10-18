module Types
  class MutationType < BaseObject
    field :create_payroll_run, mutation: Mutations::CreatePayrollRun
    field :calculate_payroll_run, mutation: Mutations::CalculatePayrollRun
    field :confirm_payroll_run, mutation: Mutations::ConfirmPayrollRun
    field :import_attendance_summaries, mutation: Mutations::ImportAttendanceSummaries
  end
end
