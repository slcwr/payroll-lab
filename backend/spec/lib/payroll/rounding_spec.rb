# frozen_string_literal: true

require_relative "../../domain_helper"

RSpec.describe Payroll::Rounding do
  describe ".social_insurance（50銭以下切り捨て・50銭超切り上げ）" do
    it { expect(described_class.social_insurance(BigDecimal("20192.5"))).to eq 20_192 }
    it { expect(described_class.social_insurance(BigDecimal("20192.51"))).to eq 20_193 }
    it { expect(described_class.social_insurance(BigDecimal("20192.49"))).to eq 20_192 }
    it { expect(described_class.social_insurance(BigDecimal("20192"))).to eq 20_192 }
  end

  describe ".half_up（50銭以上切り上げ）" do
    it { expect(described_class.half_up(BigDecimal("100.5"))).to eq 101 }
    it { expect(described_class.half_up(BigDecimal("100.49"))).to eq 100 }
  end

  describe ".half_up_to_ten（10円未満四捨五入）" do
    it { expect(described_class.half_up_to_ten(BigDecimal("7912.69"))).to eq 7_910 }
    it { expect(described_class.half_up_to_ten(BigDecimal("7915"))).to eq 7_920 }
  end

  describe ".ceil" do
    it { expect(described_class.ceil(BigDecimal("133603.4"))).to eq 133_604 }
  end
end
