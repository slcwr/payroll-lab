# bin/rails db:seed
# 件数を変える場合: SEED_EMPLOYEES=10000 bin/rails db:seed
count = ENV.fetch("SEED_EMPLOYEES", 300).to_i

company = Company.find_or_create_by!(name: "株式会社サンプル") do |c|
  c.prefecture = "tokyo"
  c.monthly_scheduled_hours = 160
  c.monthly_scheduled_days = 20
end

if company.employees.none?
  SeedData.create_employees(company, count, year_month: "2026-10")
  puts "従業員 #{count} 人を作成しました"
end

company.payroll_runs.find_or_create_by!(year_month: "2026-10") { _1.payment_date = Date.new(2026, 11, 25) }
puts "2026年10月分の給与計算（未計算）を作成しました"
