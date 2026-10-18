# frozen_string_literal: true

module Payroll
  module Steps
    # 支給の計算: 基本給・固定手当・割増賃金・欠勤控除・通勤手当
    class Earnings
      OVERTIME_RATE = BigDecimal("1.25")          # 法定時間外（月60時間まで）
      OVERTIME_OVER_60H_RATE = BigDecimal("1.50") # 法定時間外（月60時間超）
      LATE_NIGHT_PREMIUM = BigDecimal("0.25")     # 深夜（割増分のみ。労働時間自体は時間外・所定内で支払済み）
      LEGAL_HOLIDAY_RATE = BigDecimal("1.35")     # 法定休日
      OVERTIME_60H_MINUTES = 60 * 60
      COMMUTE_NON_TAXABLE_LIMIT = 150_000         # 通勤手当の非課税限度額（電車・バス等）

      def call(ctx)
        e = ctx.employee
        days = Eligibility.enrolled_days(hired_on: e.hired_on, retired_on: e.retired_on, period: ctx.period)
        return if days.zero?

        ratio = Rational(days, ctx.period.days)
        add_base_and_allowances(ctx, ratio, days)
        add_premiums(ctx)
        add_absence(ctx)
        add_commute(ctx)
      end

      private

      def add_base_and_allowances(ctx, ratio, days)
        e = ctx.employee
        prorated = ratio != 1
        note = prorated ? "日割り（在籍#{days}日 / 暦日#{ctx.period.days}日）" : nil
        ctx.warn("月の途中の入退社のため基本給・手当を日割り計算しました") if prorated

        ctx.add(code: "BASE", name: "基本給", category: :earning, taxable: true,
                amount: prorate(e.base_salary, ratio), basis: note)
        e.allowances.each do |a|
          ctx.add(code: "ALW_#{a.code}", name: a.name, category: :earning, taxable: a.taxable,
                  amount: prorate(a.amount, ratio), basis: note)
        end
      end

      def add_premiums(ctx)
        at = ctx.attendance
        unit = hourly_unit(ctx)
        unit_note = "時間単価#{yen(unit)}"

        if at.overtime_minutes.positive?
          within = [at.overtime_minutes, OVERTIME_60H_MINUTES].min
          over = at.overtime_minutes - within
          ctx.add(code: "OVERTIME", name: "時間外手当", category: :earning, taxable: true,
                  amount: premium(unit, OVERTIME_RATE, within),
                  basis: "#{unit_note} × #{hours(within)} × #{Format.decimal(OVERTIME_RATE)}")
          if over.positive?
            ctx.add(code: "OVERTIME_60H", name: "時間外手当（60時間超）", category: :earning, taxable: true,
                    amount: premium(unit, OVERTIME_OVER_60H_RATE, over),
                    basis: "#{unit_note} × #{hours(over)} × #{Format.decimal(OVERTIME_OVER_60H_RATE)}")
          end
        end
        if at.late_night_minutes.positive?
          ctx.add(code: "LATE_NIGHT", name: "深夜手当", category: :earning, taxable: true,
                  amount: premium(unit, LATE_NIGHT_PREMIUM, at.late_night_minutes),
                  basis: "#{unit_note} × #{hours(at.late_night_minutes)} × #{Format.decimal(LATE_NIGHT_PREMIUM)}")
        end
        return unless at.legal_holiday_minutes.positive?

        ctx.add(code: "HOLIDAY", name: "休日手当", category: :earning, taxable: true,
                amount: premium(unit, LEGAL_HOLIDAY_RATE, at.legal_holiday_minutes),
                basis: "#{unit_note} × #{hours(at.legal_holiday_minutes)} × #{Format.decimal(LEGAL_HOLIDAY_RATE)}")
      end

      def add_absence(ctx)
        at = ctx.attendance
        e = ctx.employee
        if at.absence_days.positive?
          daily = BigDecimal(e.base_salary) / ctx.rules.monthly_scheduled_days
          ctx.add(code: "ABSENCE", name: "欠勤控除", category: :earning, taxable: true,
                  amount: -Rounding.half_up(daily * at.absence_days),
                  basis: "基本給#{yen(e.base_salary)} ÷ 所定#{Format.decimal(ctx.rules.monthly_scheduled_days)}日 × #{at.absence_days}日")
        end
        return unless at.late_early_minutes.positive?

        unit = hourly_unit(ctx)
        ctx.add(code: "LATE_EARLY", name: "遅刻早退控除", category: :earning, taxable: true,
                amount: -Rounding.half_up(unit * Rational(at.late_early_minutes, 60)),
                basis: "時間単価#{yen(unit)} × #{hours(at.late_early_minutes)}")
      end

      def add_commute(ctx)
        amount = ctx.employee.commute_allowance
        return unless amount.positive?

        non_taxable = [amount, COMMUTE_NON_TAXABLE_LIMIT].min
        ctx.add(code: "COMMUTE", name: "通勤手当", category: :earning, taxable: false, amount: non_taxable,
                basis: "非課税（限度額#{yen(COMMUTE_NON_TAXABLE_LIMIT)}）")
        return unless amount > non_taxable

        ctx.add(code: "COMMUTE_TAXABLE", name: "通勤手当（課税分）", category: :earning, taxable: true,
                amount: amount - non_taxable, basis: "非課税限度額を超える部分")
      end

      # 割増賃金の算定基礎となる1時間当たりの賃金（円未満四捨五入）。
      # 住宅手当・家族手当など除外賃金は Allowance#overtime_base = false で算定基礎から外す。
      def hourly_unit(ctx)
        e = ctx.employee
        base = e.base_salary + e.allowances.select(&:overtime_base).sum(&:amount)
        Rounding.half_up(BigDecimal(base) / ctx.rules.monthly_scheduled_hours)
      end

      def premium(unit, rate, minutes)
        Rounding.half_up(unit * rate * Rational(minutes, 60))
      end

      def prorate(amount, ratio)
        ratio == 1 ? amount : Rounding.half_up(amount * ratio)
      end

      def hours(minutes) = Format.hours(minutes)
      def yen(value) = Format.yen(value)
    end
  end
end
