# frozen_string_literal: true

require_relative "../../domain_helper"

RSpec.describe Payroll::Eligibility do
  describe "年齢到達日は誕生日の前日" do
    it "4月1日生まれは3月が40歳の到達月" do
      birth = Date.new(1986, 4, 1)
      expect(described_class.reaches_age_in_month?(birth, 40, Date.new(2026, 3, 1))).to be true
      expect(described_class.nursing_care_insured?(birth, Date.new(2026, 3, 1))).to be true
      expect(described_class.nursing_care_insured?(birth, Date.new(2026, 2, 1))).to be false
    end

    it "4月2日生まれは4月が到達月" do
      birth = Date.new(1986, 4, 2)
      expect(described_class.nursing_care_insured?(birth, Date.new(2026, 3, 1))).to be false
      expect(described_class.nursing_care_insured?(birth, Date.new(2026, 4, 1))).to be true
    end

    it "2月29日生まれも扱える" do
      birth = Date.new(1988, 2, 29)
      expect(described_class.age_reached_on(birth, 40)).to eq Date.new(2028, 2, 28)
    end
  end

  describe "介護保険は65歳到達月から対象外" do
    it do
      birth = Date.new(1961, 10, 15) # 2026-10-14 に65歳到達
      expect(described_class.nursing_care_insured?(birth, Date.new(2026, 9, 1))).to be true
      expect(described_class.nursing_care_insured?(birth, Date.new(2026, 10, 1))).to be false
    end
  end

  describe "健康保険は75歳の誕生日の月から対象外（後期高齢者医療へ）" do
    it do
      birth = Date.new(1951, 10, 1)
      expect(described_class.health_insured?(birth, Date.new(2026, 9, 1))).to be true
      expect(described_class.health_insured?(birth, Date.new(2026, 10, 1))).to be false
    end
  end

  describe ".social_insurance_month?（資格取得月〜喪失月の前月）" do
    let(:hired) { Date.new(2026, 4, 15) }

    it "取得月は対象（月の途中の入社でも1か月分）" do
      expect(described_class.social_insurance_month?(hired_on: hired, retired_on: nil, month_start: Date.new(2026, 4, 1))).to be true
    end

    it "入社前の月は対象外" do
      expect(described_class.social_insurance_month?(hired_on: hired, retired_on: nil, month_start: Date.new(2026, 3, 1))).to be false
    end

    it "月末退職は喪失日が翌月1日なので退職月も対象" do
      expect(described_class.social_insurance_month?(hired_on: hired, retired_on: Date.new(2026, 10, 31), month_start: Date.new(2026, 10, 1))).to be true
    end

    it "月の途中で退職すると退職月は対象外" do
      expect(described_class.social_insurance_month?(hired_on: hired, retired_on: Date.new(2026, 10, 30), month_start: Date.new(2026, 10, 1))).to be false
    end
  end
end
