module Mutations
  class CreatePayrollRun < BaseMutation
    description "対象月の給与計算を作成する（まだ計算はしない）"

    argument :year_month, String, description: "対象月（例: 2026-10）"
    argument :payment_date, GraphQL::Types::ISO8601Date, description: "支給日"

    field :payroll_run, Types::PayrollRunType

    def resolve(year_month:, payment_date:)
      run = current_company.payroll_runs.new(year_month: year_month, payment_date: payment_date)
      return failure(run.errors.full_messages, payroll_run: nil) unless run.save

      { payroll_run: run, errors: [] }
    end
  end
end
