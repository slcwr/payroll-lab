# frozen_string_literal: true

module Payroll
  module Steps
    # 健康保険・介護保険・子ども子育て支援金・厚生年金（被保険者負担分）
    #
    # - 保険料は「対象月」で料率が決まる（例: 令和8年度の協会けんぽ料率は3月分から）
    # - 翌月徴収の会社では、当月の給与から「前月分」の保険料を控除する
    # - 退職日が月末の場合は資格喪失日が翌月1日になり、最後の給与で前月分と当月分の2か月分を控除する
    class SocialInsurance
      CODES = %w[HEALTH NURSING CHILD_SUPPORT PENSION].freeze

      def call(ctx)
        e = ctx.employee
        return unless e.social_insurance_enrolled

        months = coverage_months(ctx).select do |m|
          Eligibility.social_insurance_month?(hired_on: e.hired_on, retired_on: e.retired_on, month_start: m)
        end
        return if months.empty?

        std = e.standard_monthly_remuneration
        unless std&.positive?
          ctx.warn("標準報酬月額が未登録のため社会保険料を計算できませんでした")
          return
        end

        months.each { |m| add_month(ctx, m, std, label: months.size > 1 ? "#{m.month}月分" : nil) }
      end

      private

      def coverage_months(ctx)
        p = ctx.period
        return [p.start_date] if ctx.rules.social_insurance_collection == :current_month

        months = [p.previous_month_start]
        retired = ctx.employee.retired_on
        # 翌月徴収でも、退職月の分は翌月の給与がないため最後の給与でまとめて控除する
        months << p.start_date if retired && p.range.cover?(retired)
        months
      end

      def add_month(ctx, month, std, label:)
        e = ctx.employee
        rt = ctx.rate_table
        suffix = label ? "（#{label}）" : ""
        month_note = "#{month.year}年#{month.month}月分"

        if Eligibility.health_insured?(e.birth_date, month)
          rate = rt.health_insurance(month, prefecture: ctx.rules.prefecture)
          add(ctx, "HEALTH", "健康保険料#{suffix}", std, rate, month_note)

          if Eligibility.nursing_care_insured?(e.birth_date, month)
            add(ctx, "NURSING", "介護保険料#{suffix}", std, rt.nursing_care(month), month_note)
          end

          child = rt.child_support(month)
          add(ctx, "CHILD_SUPPORT", "子ども・子育て支援金#{suffix}", std, child, month_note) if child.positive?
        end

        return unless Eligibility.welfare_pension_insured?(e.birth_date, month)

        pension = rt.welfare_pension(month)
        pension_std = [std, pension.standard_remuneration_cap].min
        add(ctx, "PENSION", "厚生年金保険料#{suffix}", pension_std, pension.rate, month_note)
      end

      def add(ctx, code, name, std, rate, month_note)
        ctx.add(code: code, name: name, category: :deduction,
                amount: Rounding.social_insurance(std * rate / 2),
                basis: "標準報酬月額#{Format.yen(std)} × #{Format.percent(rate)} ÷ 2（#{month_note}）")
      end
    end
  end
end
