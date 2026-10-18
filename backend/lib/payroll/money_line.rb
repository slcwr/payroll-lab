# frozen_string_literal: true

module Payroll
  # 明細の1行。
  # basis（計算根拠）を必ず残すことで、担当者のチェック作業・問い合わせ対応・監査に使えるようにする。
  MoneyLine = Data.define(:code, :name, :category, :amount, :taxable, :basis)

  class MoneyLine
    CATEGORIES = %i[earning deduction].freeze

    def initialize(code:, name:, category:, amount:, taxable: false, basis: nil)
      raise ArgumentError, "unknown category: #{category}" unless CATEGORIES.include?(category)
      raise ArgumentError, "amount must be Integer (yen): #{amount.inspect}" unless amount.is_a?(Integer)

      super
    end

    def earning? = category == :earning
    def deduction? = category == :deduction
  end
end
