module Types
  class QueryType < BaseObject
    field :company, CompanyType, null: false

    field :payroll_runs, [PayrollRunType], null: false, description: "給与計算の一覧（新しい順）"

    field :payroll_run, PayrollRunType do
      argument :id, ID
    end

    field :payslip, PayslipType do
      argument :id, ID
    end

    def company = current_company

    def payroll_runs = current_company.payroll_runs.order(year_month: :desc)

    def payroll_run(id:) = current_company.payroll_runs.find(id)

    # 他社の明細を id 指定で覗けないよう、必ず会社で絞ってから引く
    def payslip(id:) = Payslip.joins(:payroll_run).where(payroll_runs: { company_id: current_company.id }).find(id)

    private

    def current_company = context.fetch(:current_company)
  end
end
