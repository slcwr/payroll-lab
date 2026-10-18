# frozen_string_literal: true

module Payroll
  module Steps
    # 住民税（特別徴収）。市区町村から通知された月額をそのまま控除する。
    class ResidentTax
      def call(ctx)
        amount = ctx.employee.resident_tax_monthly.to_i
        return unless amount.positive?

        ctx.add(code: "RESIDENT_TAX", name: "住民税", category: :deduction, amount: amount, basis: "特別徴収税額通知書の月額")
      end
    end
  end
end
