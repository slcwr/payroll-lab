class PayslipLine < ApplicationRecord
  belongs_to :payslip

  enum :category, { earning: "earning", deduction: "deduction" }
end
