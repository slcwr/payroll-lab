class EmployeeAllowance < ApplicationRecord
  belongs_to :employee
  belongs_to :pay_item

  validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :pay_item_id, uniqueness: { scope: :employee_id }

  def to_payroll_allowance
    Payroll::Allowance.new(code: pay_item.code, name: pay_item.name, amount: amount,
                           taxable: pay_item.taxable, overtime_base: pay_item.overtime_base)
  end
end
