# frozen_string_literal: true

require_relative "../../domain_helper"

RSpec.describe Payroll::Versioned do
  subject(:versioned) do
    described_class.new([
      { effective_from: "2026-04-01", value: :new },
      { effective_from: "2025-04-01", value: :old }
    ])
  end

  it "指定日に有効な値を返す（順不同で登録してよい）" do
    expect(versioned.at(Date.new(2026, 3, 31))).to eq :old
    expect(versioned.at(Date.new(2026, 4, 1))).to eq :new
  end

  it "適用前の日付は nil" do
    expect(versioned.at(Date.new(2025, 1, 1))).to be_nil
  end

  it "適用開始日の重複はエラー（データ投入ミスを防ぐ）" do
    expect do
      described_class.new([{ effective_from: "2026-04-01", value: 1 }, { effective_from: "2026-04-01", value: 2 }])
    end.to raise_error(Payroll::Error, /重複/)
  end
end
