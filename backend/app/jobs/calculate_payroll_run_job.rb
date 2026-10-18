class CalculatePayrollRunJob < ApplicationJob
  queue_as :payroll

  def perform(payroll_run_id)
    PayrollRuns::Calculate.call(PayrollRun.find(payroll_run_id))
  end
end
