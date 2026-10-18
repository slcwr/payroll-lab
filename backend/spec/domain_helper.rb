# frozen_string_literal: true

# Rails を起動せずに給与計算ドメイン層だけをテストするためのヘルパー。
#   bundle exec rspec spec/lib/payroll
# DB もフレームワークも不要なので数百ケースでも一瞬で終わる。
require_relative "../lib/payroll"
Payroll.require_all!

module PayrollSpecHelpers
  def work_rules(**overrides)
    Payroll::WorkRules.new(
      prefecture: "tokyo", employment_insurance_business: :general, social_insurance_collection: :next_month,
      monthly_scheduled_hours: 160, monthly_scheduled_days: 20, **overrides
    )
  end

  def employee(**overrides)
    Payroll::EmployeeSnapshot.new(
      id: 1, code: "E0001", name: "山田 花子", birth_date: Date.new(1981, 5, 10), hired_on: Date.new(2020, 4, 1),
      base_salary: 300_000, standard_monthly_remuneration: 300_000, **overrides
    )
  end

  def attendance(**overrides) = Payroll::AttendanceSummary.new(**overrides)

  def period(year_month = "2026-10", payment_date: nil)
    y, m = year_month.split("-").map(&:to_i)
    Payroll::Period.of(year_month, payment_date: payment_date || Date.new(y, m, 1).next_month + 24)
  end

  def calculate(employee:, attendance: self.attendance, period: self.period, rules: work_rules)
    Payroll::Calculator.new(rules: rules).calculate(employee: employee, attendance: attendance, period: period)
  end
end

RSpec.configure do |config|
  config.include PayrollSpecHelpers
  config.disable_monkey_patching!
  config.order = :random
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
