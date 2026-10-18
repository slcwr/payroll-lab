# frozen_string_literal: true

module Payroll
  # 1人分の給与を計算する。
  #
  #   calculator = Payroll::Calculator.new(rules: work_rules)
  #   result = calculator.calculate(employee: snapshot, attendance: summary, period: period)
  #
  # 計算は副作用のない純粋関数として扱う（同じ入力なら必ず同じ結果）。
  # 再計算・並列実行・テストがしやすく、数万人規模のバッチでもワーカーを増やすだけで並列化できる。
  class Calculator
    STEPS = [
      Steps::Earnings,
      Steps::SocialInsurance,
      Steps::EmploymentInsurance,
      Steps::IncomeTax,
      Steps::ResidentTax
    ].freeze

    def initialize(rules:, rate_table: RateTable.default, tax_table: WithholdingTaxTable.default)
      @rules = rules
      @rate_table = rate_table
      @tax_table = tax_table
      @steps = STEPS.map(&:new)
    end

    def calculate(employee:, attendance:, period:)
      ctx = Context.new(employee: employee, attendance: attendance || AttendanceSummary.empty, period: period,
                        rules: @rules, rate_table: @rate_table, tax_table: @tax_table)
      ctx.warn("勤怠集計が連携されていません（時間外・欠勤を0として計算）") if attendance.nil?

      @steps.each { |step| step.call(ctx) }
      Result.build(ctx, flags: flags_for(ctx))
    end

    private

    # 計算結果のチェックで絞り込みに使う目印
    def flags_for(ctx)
      e = ctx.employee
      p = ctx.period
      flags = []
      flags << "hired_in_period" if p.range.cover?(e.hired_on)
      flags << "retired_in_period" if e.retired_on && p.range.cover?(e.retired_on)
      flags << "negative_net" if ctx.gross_pay - ctx.deductions.sum(&:amount) < 0
      [40, 65, 70].each do |age|
        flags << "age_#{age}" if Eligibility.reaches_age_in_month?(e.birth_date, age, p.start_date)
      end
      b75 = e.birth_date.next_year(75)
      flags << "age_75" if b75.year == p.year && b75.month == p.month
      flags << "has_warning" if ctx.warnings.any?
      flags
    end
  end
end
