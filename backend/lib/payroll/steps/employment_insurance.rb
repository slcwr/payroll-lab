# frozen_string_literal: true

module Payroll
  module Steps
    # 雇用保険料（労働者負担分）
    # 賃金総額（通勤手当を含む、税金・社会保険料控除前）× 労働者負担率。
    # 料率は賃金締切日時点のものを使う（年度の切り替えは4月1日以降に締切日が来る賃金から）。
    class EmploymentInsurance
      def call(ctx)
        return unless ctx.employee.employment_insurance_enrolled

        wage = ctx.gross_pay
        return unless wage.positive?

        rate = ctx.rate_table.employment_insurance(ctx.period.closing_date, business: ctx.rules.employment_insurance_business)
        ctx.add(code: "EMPLOYMENT", name: "雇用保険料", category: :deduction,
                amount: Rounding.social_insurance(wage * rate),
                basis: "賃金総額#{Format.yen(wage)} × #{Format.per_mille(rate)}")
      end
    end
  end
end
