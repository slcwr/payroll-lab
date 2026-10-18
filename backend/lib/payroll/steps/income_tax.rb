# frozen_string_literal: true

module Payroll
  module Steps
    # 源泉所得税（月額表・甲欄、電算機計算の特例）
    class IncomeTax
      SOCIAL_CODES = (SocialInsurance::CODES + %w[EMPLOYMENT]).freeze

      def call(ctx)
        e = ctx.employee
        social = ctx.deductions_with_codes(*SOCIAL_CODES)
        a = ctx.taxable_pay - social
        r = ctx.tax_table.calculate(a: a, payment_date: ctx.period.payment_date,
                                    spouse: e.withholding_spouse, dependents: e.dependents_count)
        return unless r.tax.positive?

        ctx.add(code: "INCOME_TAX", name: "所得税", category: :deduction, amount: r.tax,
                basis: "#{r.version_name}・甲欄 / A=#{yen(r.a)}（課税支給#{yen(ctx.taxable_pay)} − 社会保険料等#{yen(social)}） " \
                       "/ 扶養等#{e.dependents_count + (e.withholding_spouse ? 1 : 0)}人 / B=#{yen(r.b)}")
      end

      private

      def yen(value) = Format.yen(value)
    end
  end
end
