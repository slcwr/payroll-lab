# frozen_string_literal: true

require_relative "../../domain_helper"

RSpec.describe Payroll::Calculator do
  let(:allowances) do
    [
      Payroll::Allowance.new(code: "POSITION", name: "役職手当", amount: 20_000),
      # 住宅手当（一律でないもの）は割増賃金の算定基礎から除外できる
      Payroll::Allowance.new(code: "HOUSING", name: "住宅手当", amount: 15_000, overtime_base: false)
    ]
  end

  describe "支給" do
    let(:emp) { employee(allowances: allowances, commute_allowance: 160_000) }
    let(:result) do
      calculate(employee: emp, attendance: attendance(overtime_minutes: 70 * 60, late_night_minutes: 5 * 60,
                                                      legal_holiday_minutes: 8 * 60, absence_days: 1, late_early_minutes: 30))
    end

    it "時間単価は（基本給＋算定基礎に含む手当）÷ 月平均所定労働時間" do
      expect(result.line("OVERTIME").basis).to start_with "時間単価2,000円"
    end

    it "時間外は60時間まで1.25倍、60時間超は1.5倍" do
      expect(result.amount_of("OVERTIME")).to eq 150_000
      expect(result.amount_of("OVERTIME_60H")).to eq 30_000
    end

    it "深夜は割増分0.25倍、法定休日は1.35倍" do
      expect(result.amount_of("LATE_NIGHT")).to eq 2_500
      expect(result.amount_of("HOLIDAY")).to eq 21_600
    end

    it "欠勤・遅刻早退はマイナスの支給として控除する" do
      expect(result.amount_of("ABSENCE")).to eq(-15_000)
      expect(result.amount_of("LATE_EARLY")).to eq(-1_000)
    end

    it "通勤手当は15万円まで非課税、超えた分は課税" do
      expect(result.line("COMMUTE")).to have_attributes(amount: 150_000, taxable: false)
      expect(result.line("COMMUTE_TAXABLE")).to have_attributes(amount: 10_000, taxable: true)
    end
  end

  describe "1人分の通し計算（2026年10月分・11月25日払い・翌月徴収）" do
    let(:emp) do
      employee(allowances: allowances, commute_allowance: 160_000, dependents_count: 1, resident_tax_monthly: 15_000)
    end
    let(:result) do
      calculate(employee: emp, attendance: attendance(overtime_minutes: 70 * 60, late_night_minutes: 5 * 60,
                                                      legal_holiday_minutes: 8 * 60, absence_days: 1, late_early_minutes: 30))
    end

    it "支給合計と課税支給額" do
      expect(result.gross_pay).to eq 683_100
      expect(result.taxable_pay).to eq 533_100
    end

    it "社会保険料は9月分（令和8年度・東京）の料率" do
      expect(result.amount_of("HEALTH")).to eq 14_775
      expect(result.amount_of("NURSING")).to eq 2_430   # 45歳なので介護保険の対象
      expect(result.amount_of("CHILD_SUPPORT")).to eq 345
      expect(result.amount_of("PENSION")).to eq 27_450
    end

    it "雇用保険料は賃金総額×5/1000（3,415.5円 → 50銭以下切り捨て）" do
      expect(result.amount_of("EMPLOYMENT")).to eq 3_415
    end

    it "所得税は課税支給額から社会保険料等を引いた額で求める" do
      expect(result.amount_of("INCOME_TAX")).to eq 19_380
      expect(result.line("INCOME_TAX").basis).to include("A=484,685円")
    end

    it "差引支給額" do
      expect(result.total_deductions).to eq 82_795
      expect(result.net_pay).to eq 600_305
      expect(result.warnings).to be_empty
    end
  end

  describe "法改正の切り替え" do
    let(:emp) { employee }

    it "2026年4月分（3月分保険料）は子ども・子育て支援金なし、5月分（4月分保険料）からあり" do
      april = calculate(employee: emp, period: period("2026-04"))
      may = calculate(employee: emp, period: period("2026-05"))
      expect(april.line("CHILD_SUPPORT")).to be_nil
      expect(april.amount_of("HEALTH")).to eq 14_775 # 3月分から令和8年度料率
      expect(may.amount_of("CHILD_SUPPORT")).to eq 345
    end

    it "当月徴収の会社では2026年4月分の給与から支援金を控除する" do
      r = calculate(employee: emp, period: period("2026-04"), rules: work_rules(social_insurance_collection: :current_month))
      expect(r.amount_of("CHILD_SUPPORT")).to eq 345
    end

    it "雇用保険料は賃金締切日が4月1日以降の賃金から新料率" do
      march = calculate(employee: emp, period: period("2026-03"))
      april = calculate(employee: emp, period: period("2026-04"))
      expect(march.amount_of("EMPLOYMENT")).to eq 1_650 # 5.5/1000
      expect(april.amount_of("EMPLOYMENT")).to eq 1_500 # 5/1000
    end
  end

  describe "標準報酬月額と端数" do
    it "被保険者負担の50銭は切り捨て" do
      r = calculate(employee: employee(standard_monthly_remuneration: 410_000))
      expect(r.amount_of("HEALTH")).to eq 20_192 # 410,000 × 9.85% ÷ 2 = 20,192.5
    end

    it "厚生年金は標準報酬月額の上限（65万円）で頭打ち" do
      r = calculate(employee: employee(standard_monthly_remuneration: 800_000))
      expect(r.amount_of("PENSION")).to eq 59_475
    end
  end

  describe "入社・退職" do
    it "月の途中の入社は暦日で日割りし、翌月徴収なので社会保険料は控除しない" do
      r = calculate(employee: employee(hired_on: Date.new(2026, 10, 16)))
      expect(r.amount_of("BASE")).to eq 154_839 # 300,000 × 16/31
      expect(r.line("HEALTH")).to be_nil
      expect(r.flags).to include("hired_in_period")
      expect(r.warnings).to include(match(/日割り/))
    end

    it "月末退職は最後の給与で前月分と当月分の2か月分を控除する" do
      r = calculate(employee: employee(retired_on: Date.new(2026, 10, 31)))
      health = r.lines.select { _1.code == "HEALTH" }
      expect(health.map(&:name)).to eq ["健康保険料（9月分）", "健康保険料（10月分）"]
      expect(r.flags).to include("retired_in_period")
    end

    it "月の途中の退職は前月分のみ" do
      r = calculate(employee: employee(retired_on: Date.new(2026, 10, 20)))
      expect(r.lines.count { _1.code == "HEALTH" }).to eq 1
    end
  end

  describe "年齢による扱い" do
    it "40歳到達月を目印として付ける" do
      r = calculate(employee: employee(birth_date: Date.new(1986, 10, 20)))
      expect(r.flags).to include("age_40")
    end

    it "70歳以上は厚生年金保険料なし" do
      r = calculate(employee: employee(birth_date: Date.new(1955, 1, 10)))
      expect(r.line("PENSION")).to be_nil
      expect(r.line("NURSING")).to be_nil
      expect(r.line("HEALTH")).not_to be_nil
    end
  end

  describe "データ不備の検知" do
    it "勤怠が連携されていなければ警告を出す" do
      r = Payroll::Calculator.new(rules: work_rules).calculate(employee: employee, attendance: nil, period: period)
      expect(r.warnings).to include(match(/勤怠集計が連携されていません/))
      expect(r.flags).to include("has_warning")
    end

    it "標準報酬月額が未登録なら社会保険料を計算せず警告" do
      r = calculate(employee: employee(standard_monthly_remuneration: nil))
      expect(r.line("HEALTH")).to be_nil
      expect(r.warnings).to include(match(/標準報酬月額/))
    end

    it "差引支給額がマイナスなら目印を付ける" do
      r = calculate(employee: employee(base_salary: 100_000, resident_tax_monthly: 120_000))
      expect(r.net_pay).to be_negative
      expect(r.flags).to include("negative_net")
    end
  end

  describe "計算の性質" do
    it "同じ入力なら必ず同じ結果（冪等）" do
      emp = employee(allowances: allowances)
      at = attendance(overtime_minutes: 1234)
      expect(calculate(employee: emp, attendance: at)).to eq calculate(employee: emp, attendance: at)
    end

    it "支給合計 − 控除合計 = 差引支給額" do
      r = calculate(employee: employee(allowances: allowances, dependents_count: 2, resident_tax_monthly: 9_000))
      expect(r.lines.select(&:earning?).sum(&:amount) - r.lines.select(&:deduction?).sum(&:amount)).to eq r.net_pay
    end
  end
end
