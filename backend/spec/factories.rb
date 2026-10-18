FactoryBot.define do
  factory :company do
    name { "テスト株式会社" }
    prefecture { "tokyo" }
    monthly_scheduled_hours { 160 }
    monthly_scheduled_days { 20 }
  end

  factory :pay_item do
    company
    sequence(:code) { "ITEM#{_1}" }
    name { "手当" }
  end

  factory :employee do
    company
    sequence(:code) { format("E%05d", _1) }
    name { "山田 花子" }
    birth_date { Date.new(1981, 5, 10) }
    hired_on { Date.new(2020, 4, 1) }
    base_salary { 300_000 }
    standard_monthly_remuneration { 300_000 }
  end

  factory :employee_allowance do
    employee
    pay_item { association :pay_item, company: employee.company }
    amount { 20_000 }
  end

  factory :attendance_summary do
    employee
    year_month { "2026-10" }
  end

  factory :payroll_run do
    company
    year_month { "2026-10" }
    payment_date { Date.new(2026, 11, 25) }
  end
end
