module Mutations
  class CalculatePayrollRun < BaseMutation
    description "給与計算を実行する（非同期）。進捗は payrollRun.status / progress で確認する"

    argument :id, ID

    field :payroll_run, Types::PayrollRunType

    def resolve(id:)
      run = find_run(id)
      PayrollRuns::Dispatcher.call(run)
      { payroll_run: run.reload, errors: [] }
    rescue PayrollRun::InvalidTransition => e
      failure(e.message, payroll_run: run)
    end
  end
end
