# frozen_string_literal: true

require_relative "../../domain_helper"

RSpec.describe Payroll::WithholdingTaxTable do
  subject(:table) { described_class.default }

  def tax(a, payment_date:, spouse: false, dependents: 0)
    table.calculate(a: a, payment_date: payment_date, spouse: spouse, dependents: dependents)
  end

  describe "年分の切り替え（支払日で決まる）" do
    it "2025年12月25日払いは令和7年分" do
      expect(tax(300_000, payment_date: Date.new(2025, 12, 25)).version_name).to eq "令和7年分"
    end

    it "12月分の給与でも翌年1月払いなら令和8年分" do
      expect(tax(300_000, payment_date: Date.new(2026, 1, 25)).version_name).to eq "令和8年分"
    end

    it "未設定の年分はエラー" do
      expect { tax(300_000, payment_date: Date.new(2024, 12, 25)) }.to raise_error(Payroll::Error, /未設定/)
    end
  end

  describe "令和8年分" do
    let(:date) { Date.new(2026, 11, 25) }

    it "A=300,000円・扶養0人" do
      r = tax(300_000, payment_date: date)
      expect([r.employment_income_deduction, r.basic_deduction, r.b, r.tax]).to eq [96_667, 48_334, 154_999, 7_910]
    end

    it "A=150,000円は給与所得控除が定額（54,167円）" do
      r = tax(150_000, payment_date: date)
      expect([r.employment_income_deduction, r.b, r.tax]).to eq [54_167, 47_499, 2_420]
    end

    it "A=1,000,000円・配偶者あり・扶養2人" do
      r = tax(1_000_000, payment_date: date, spouse: true, dependents: 2)
      expect([r.spouse_deduction, r.dependent_deduction, r.b, r.tax]).to eq [31_667, 63_334, 694_165, 108_900]
    end

    it "控除後がマイナスなら税額0" do
      expect(tax(80_000, payment_date: date).tax).to eq 0
    end
  end

  describe "令和7年分との比較（基礎控除の引き上げで税額が下がる）" do
    it "A=300,000円・扶養0人" do
      r7 = tax(300_000, payment_date: Date.new(2025, 11, 25))
      r8 = tax(300_000, payment_date: Date.new(2026, 11, 25))
      expect(r7.tax).to eq 8_380
      expect(r8.tax).to be < r7.tax
    end

    it "A=150,000円は令和7年分では算式で給与所得控除を求める" do
      r7 = tax(150_000, payment_date: Date.new(2025, 11, 25))
      expect([r7.employment_income_deduction, r7.tax]).to eq [51_667, 2_980]
    end
  end
end
