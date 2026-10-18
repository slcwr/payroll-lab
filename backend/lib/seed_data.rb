# 開発用・ベンチマーク用のデータを作る。
# 大量件数でも速く作れるよう insert_all を使う。
module SeedData
  # 協会けんぽの標準報酬月額の等級（シード用に近い等級を選ぶためだけに使う）
  STANDARD_GRADES = [
    58, 68, 78, 88, 98, 104, 110, 118, 126, 134, 142, 150, 160, 170, 180, 190, 200, 220, 240, 260, 280, 300,
    320, 340, 360, 380, 410, 440, 470, 500, 530, 560, 590, 620, 650, 680, 710, 750, 790, 830, 880, 930, 980,
    1030, 1090, 1150, 1210, 1270, 1330, 1390
  ].map { _1 * 1000 }.freeze

  LAST_NAMES = %w[佐藤 鈴木 高橋 田中 伊藤 渡辺 山本 中村 小林 加藤 吉田 山田 佐々木 山口 松本 井上 木村 林 斎藤 清水].freeze
  FIRST_NAMES = %w[翔太 陽菜 蓮 結衣 大翔 葵 悠真 凛 湊 美咲 健太 彩 拓海 さくら 颯 七海 直樹 愛 誠 優子].freeze

  PAY_ITEMS = [
    { code: "POSITION", name: "役職手当", taxable: true, overtime_base: true, position: 1 },
    { code: "QUALIFICATION", name: "資格手当", taxable: true, overtime_base: true, position: 2 },
    { code: "HOUSING", name: "住宅手当", taxable: true, overtime_base: false, position: 3 },
    { code: "FAMILY", name: "家族手当", taxable: true, overtime_base: false, position: 4 }
  ].freeze

  module_function

  def ensure_pay_items(company)
    PAY_ITEMS.each { |attrs| company.pay_items.find_or_create_by!(code: attrs[:code]) { _1.assign_attributes(attrs) } }
    company.pay_items.index_by(&:code)
  end

  # year_month を対象月として、入社・退職・年齢到達・データ不備などのパターンが混ざるように作る
  def create_employees(company, count, year_month:, random: Random.new(42))
    items = ensure_pay_items(company)
    period_start = Date.parse("#{year_month}-01")
    period_end = period_start.end_of_month
    now = Time.current
    offset = company.employees.count

    count.times.each_slice(1000) do |slice|
      rows = slice.map { |i| employee_row(company, offset + i, random, period_start, period_end, now) }
      ids = Employee.insert_all!(rows, returning: %w[id]).map { _1["id"] }

      allowances = []
      attendance = []
      ids.zip(rows).each do |id, row|
        allowances << alw(id, items["POSITION"], 30_000, now) if row[:base_salary] >= 400_000
        allowances << alw(id, items["QUALIFICATION"], 10_000, now) if random.rand < 0.3
        allowances << alw(id, items["HOUSING"], 15_000, now) if random.rand < 0.4
        allowances << alw(id, items["FAMILY"], 10_000 * row[:dependents_count], now) if row[:dependents_count].positive?
        next if random.rand < 0.02 # 2% は勤怠未連携（警告の確認用）

        attendance << {
          employee_id: id, year_month: year_month,
          overtime_minutes: (random.rand < 0.05 ? random.rand(3600..4800) : random.rand(0..2400)),
          late_night_minutes: random.rand < 0.2 ? random.rand(30..600) : 0,
          legal_holiday_minutes: random.rand < 0.1 ? random.rand(240..960) : 0,
          absence_days: random.rand < 0.05 ? random.rand(1..3) : 0,
          late_early_minutes: random.rand < 0.1 ? random.rand(10..120) : 0,
          created_at: now, updated_at: now
        }
      end
      EmployeeAllowance.insert_all!(allowances) if allowances.any?
      AttendanceSummary.insert_all!(attendance) if attendance.any?
    end
  end

  def employee_row(company, i, random, period_start, period_end, now)
    base = (random.rand(200..600) * 1000)
    hired_on =
      if random.rand < 0.02 then period_start + random.rand(0..(period_end.day - 1)) # 当月入社
      else Date.new(random.rand(2005..2025), random.rand(1..12), 1)
      end
    retired_on = hired_on < period_start && random.rand < 0.01 ? [period_end, period_start + 19].sample(random: random) : nil
    birth_date =
      case random.rand
      when 0...0.01 then period_start.prev_year(40) + random.rand(1..27) # 当月40歳到達
      when 0.01...0.015 then period_start.prev_year(70) - random.rand(30..600)
      else Date.new(random.rand(1965..2003), random.rand(1..12), random.rand(1..28))
      end
    dependents = random.rand < 0.3 ? random.rand(1..3) : 0
    commute = random.rand < 0.85 ? random.rand(5..30) * 1000 : 0
    monthly_wage = base + commute
    std = random.rand < 0.005 ? nil : STANDARD_GRADES.min_by { (_1 - monthly_wage).abs }

    {
      company_id: company.id, code: format("E%06d", i + 1),
      name: "#{LAST_NAMES.sample(random: random)} #{FIRST_NAMES.sample(random: random)}",
      birth_date: birth_date, hired_on: hired_on, retired_on: retired_on, base_salary: base,
      standard_monthly_remuneration: std, commute_allowance: commute,
      withholding_spouse: random.rand < 0.25, dependents_count: dependents,
      resident_tax_monthly: (base * 0.06 / 100).round * 100,
      social_insurance_enrolled: true, employment_insurance_enrolled: true,
      created_at: now, updated_at: now
    }
  end

  def alw(employee_id, item, amount, now)
    { employee_id: employee_id, pay_item_id: item.id, amount: amount, created_at: now, updated_at: now }
  end
end
