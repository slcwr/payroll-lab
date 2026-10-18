module Types
  class PayslipType < BaseObject
    field :id, ID, null: false
    field :employee, EmployeeType, null: false
    field :payroll_run, "Types::PayrollRunType", null: false # 相互参照になるため文字列で指定
    field :gross_pay, Int, null: false, description: "総支給額"
    field :taxable_pay, Int, null: false, description: "課税支給額"
    field :total_deductions, Int, null: false, description: "控除合計"
    field :net_pay, Int, null: false, description: "差引支給額"
    field :flags, [PayslipFlagEnum], null: false
    field :warnings, [String], null: false
    field :earnings, [PayslipLineType], null: false
    field :deductions, [PayslipLineType], null: false

    def employee = dataloader_record(Employee, object.employee_id)
    def payroll_run = dataloader_record(PayrollRun, object.payroll_run_id)
    def earnings = lines.select(&:earning?)
    def deductions = lines.select(&:deduction?)

    private

    def lines = dataloader.with(Sources::PayslipLines).load(object.id)
  end
end
