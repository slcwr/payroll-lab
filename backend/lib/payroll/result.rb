# frozen_string_literal: true

module Payroll
  # 計算の途中状態。各ステップは前のステップが積んだ明細行を参照しながら行を追加していく。
  class Context
    attr_reader :employee, :attendance, :period, :rules, :rate_table, :tax_table, :lines, :warnings

    def initialize(employee:, attendance:, period:, rules:, rate_table:, tax_table:)
      @employee = employee
      @attendance = attendance
      @period = period
      @rules = rules
      @rate_table = rate_table
      @tax_table = tax_table
      @lines = []
      @warnings = []
    end

    def add(**attrs) = (@lines << MoneyLine.new(**attrs)).last
    def warn(message) = @warnings << message

    def earnings = lines.select(&:earning?)
    def deductions = lines.select(&:deduction?)
    def gross_pay = earnings.sum(&:amount)
    def taxable_pay = earnings.select(&:taxable).sum(&:amount)
    def deductions_with_codes(*codes) = deductions.select { codes.include?(_1.code) }.sum(&:amount)
  end

  # 1人分の計算結果（給与明細）。
  Result = Data.define(:employee_id, :lines, :warnings, :flags,
                       :gross_pay, :taxable_pay, :total_deductions, :net_pay) do
    def self.build(ctx, flags:)
      gross = ctx.gross_pay
      deductions = ctx.deductions.sum(&:amount)
      new(employee_id: ctx.employee.id, lines: ctx.lines.dup.freeze, warnings: ctx.warnings.dup.freeze,
          flags: flags.freeze, gross_pay: gross, taxable_pay: ctx.taxable_pay,
          total_deductions: deductions, net_pay: gross - deductions)
    end

    def line(code) = lines.find { _1.code == code }
    def amount_of(code) = line(code)&.amount || 0
  end
end
