# frozen_string_literal: true

# フロントエンドのモック（MSW）用の明細データを、本物の計算ロジックで作って JSON に書き出す。
# Rails も DB も使わないので、どこでも実行できる。
#
#   ruby script/export_mock_payslips.rb ../frontend/src/mocks/fixtures/payslips.json
require "json"
require_relative "../lib/payroll"
Payroll.require_all!

out = ARGV.fetch(0)
random = Random.new(2026)
rules = Payroll::WorkRules.new(prefecture: "tokyo", monthly_scheduled_hours: 160, monthly_scheduled_days: 20)
period = Payroll::Period.of("2026-10", payment_date: "2026-11-25")
calculator = Payroll::Calculator.new(rules: rules)

last = %w[佐藤 鈴木 高橋 田中 伊藤 渡辺 山本 中村 小林 加藤 吉田 山田 佐々木 山口 松本 井上 木村 林 斎藤 清水]
first = %w[翔太 陽菜 蓮 結衣 大翔 葵 悠真 凛 湊 美咲 健太 彩 拓海 さくら 颯 七海 直樹 愛 誠 優子]
grades = [200, 220, 240, 260, 280, 300, 320, 340, 360, 380, 410, 440, 470, 500, 530, 560, 590, 620, 650].map { _1 * 1000 }

# チェック画面で絞り込みを試せるよう、特徴のある従業員を混ぜる
special = {
  3 => { hired_on: Date.new(2026, 10, 16) },                       # 月の途中の入社
  7 => { retired_on: Date.new(2026, 10, 31) },                     # 月末退職（2か月分控除）
  11 => { birth_date: Date.new(1986, 10, 20) },                    # 40歳到達
  15 => { birth_date: Date.new(1961, 10, 12) },                    # 65歳到達
  19 => { standard_monthly_remuneration: nil },                    # 標準報酬月額の未登録
  23 => { base_salary: 120_000, resident_tax_monthly: 140_000 },   # 差引マイナス
  27 => { birth_date: Date.new(1956, 10, 5) }                      # 70歳到達
}
no_attendance = [31]

payslips = (1..48).map do |i|
  base = random.rand(22..60) * 10_000
  commute = random.rand < 0.85 ? random.rand(5..25) * 1000 : 0
  dependents = random.rand < 0.3 ? random.rand(1..3) : 0
  allowances = []
  allowances << Payroll::Allowance.new(code: "POSITION", name: "役職手当", amount: 30_000) if base >= 400_000
  allowances << Payroll::Allowance.new(code: "HOUSING", name: "住宅手当", amount: 15_000, overtime_base: false) if random.rand < 0.4
  if dependents.positive?
    allowances << Payroll::Allowance.new(code: "FAMILY", name: "家族手当", amount: 10_000 * dependents, overtime_base: false)
  end

  attrs = {
    id: i, code: format("E%05d", i), name: "#{last.sample(random: random)} #{first.sample(random: random)}",
    birth_date: Date.new(random.rand(1968..2002), random.rand(1..12), random.rand(1..28)),
    hired_on: Date.new(random.rand(2012..2025), random.rand(1..12), 1), base_salary: base,
    standard_monthly_remuneration: grades.min_by { (_1 - base - commute).abs }, commute_allowance: commute,
    allowances: allowances, withholding_spouse: random.rand < 0.25, dependents_count: dependents,
    resident_tax_monthly: (base * 0.06 / 100).round * 100
  }.merge(special.fetch(i, {}))
  employee = Payroll::EmployeeSnapshot.new(**attrs)

  attendance = unless no_attendance.include?(i)
    Payroll::AttendanceSummary.new(
      overtime_minutes: i == 5 ? 4_500 : random.rand(0..2400),
      late_night_minutes: random.rand < 0.2 ? random.rand(30..600) : 0,
      legal_holiday_minutes: random.rand < 0.1 ? random.rand(240..960) : 0,
      absence_days: random.rand < 0.06 ? random.rand(1..2) : 0,
      late_early_minutes: random.rand < 0.1 ? random.rand(10..120) : 0
    )
  end

  r = calculator.calculate(employee: employee, attendance: attendance, period: period)
  line = ->(l) { { code: l.code, name: l.name, category: l.category.to_s.upcase, amount: l.amount, taxable: l.taxable, basis: l.basis } }
  {
    id: i.to_s,
    employee: { id: i.to_s, code: employee.code, name: employee.name, birthDate: employee.birth_date.iso8601,
                hiredOn: employee.hired_on.iso8601, retiredOn: employee.retired_on&.iso8601 },
    grossPay: r.gross_pay, taxablePay: r.taxable_pay, totalDeductions: r.total_deductions, netPay: r.net_pay,
    flags: r.flags.map(&:upcase), warnings: r.warnings,
    earnings: r.lines.select(&:earning?).map(&line), deductions: r.lines.select(&:deduction?).map(&line)
  }
end

File.write(out, JSON.pretty_generate(payslips) + "\n")
puts "#{payslips.size}件を書き出しました: #{out}"
