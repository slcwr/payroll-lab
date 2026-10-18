module Mutations
  class ConfirmPayrollRun < BaseMutation
    description "給与計算を確定する。確定後は再計算できない"

    argument :id, ID

    field :payroll_run, Types::PayrollRunType

    def resolve(id:)
      run = find_run(id)
      run.confirm!
      { payroll_run: run, errors: [] }
    rescue PayrollRun::InvalidTransition => e
      failure(e.message, payroll_run: run)
    end
  end
end
