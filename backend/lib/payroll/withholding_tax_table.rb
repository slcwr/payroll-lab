# frozen_string_literal: true

module Payroll
  # 源泉所得税（月額表・甲欄）を「電算機計算の特例」の算式で求める。
  #
  # 税額表を丸ごと持つ代わりに、財務省告示の別表（給与所得控除・基礎控除・税率）を
  # 年分ごとのデータとして持つ。年分は給与の「支払日」で決まる。
  class WithholdingTaxTable
    Version = Data.define(:effective_from, :name, :employment_income_deduction, :basic_deduction,
                          :spouse_deduction, :dependent_deduction, :brackets)
    Breakdown = Data.define(:version_name, :a, :employment_income_deduction, :basic_deduction,
                            :spouse_deduction, :dependent_deduction, :b, :tax)

    def self.load(path = File.join(Payroll.config_dir, "withholding_tax.yml"))
      new(YAML.safe_load_file(path, permitted_classes: [Date], symbolize_names: true, aliases: true))
    end

    def self.default
      @default ||= load
    end

    def initialize(data)
      @versions = Versioned.new(data.map { |v| { effective_from: v.fetch(:effective_from), value: build(v) } })
    end

    # a: 社会保険料等控除後の給与等の金額（円）
    def calculate(a:, payment_date:, spouse:, dependents:)
      v = version_at(payment_date)
      a = [a, 0].max
      eid = employment_income_deduction(v, a)
      basic = lookup(v.basic_deduction, a).fetch(:amount)
      spouse_amount = spouse ? v.spouse_deduction : 0
      dependent_amount = v.dependent_deduction * dependents
      b = a - eid - basic - spouse_amount - dependent_amount
      tax = b.positive? ? tax_for(v, b) : 0

      Breakdown.new(version_name: v.name, a: a, employment_income_deduction: eid, basic_deduction: basic,
                    spouse_deduction: spouse_amount, dependent_deduction: dependent_amount, b: b, tax: tax)
    end

    def version_at(payment_date)
      @versions.at(payment_date) or raise Error, "源泉徴収税額表が未設定です: #{payment_date}"
    end

    private

    def build(v)
      Version.new(
        effective_from: v.fetch(:effective_from), name: v.fetch(:name),
        employment_income_deduction: v.fetch(:employment_income_deduction),
        basic_deduction: v.fetch(:basic_deduction),
        spouse_deduction: v.fetch(:spouse_deduction), dependent_deduction: v.fetch(:dependent_deduction),
        brackets: v.fetch(:brackets)
      )
    end

    # 別表第一: 給与所得控除の額（1円未満切り上げ）
    def employment_income_deduction(v, a)
      row = lookup(v.employment_income_deduction, a)
      return row.fetch(:fixed) if row.key?(:fixed)

      Rounding.ceil(BigDecimal(row.fetch(:rate)) * a + row.fetch(:add))
    end

    # 別表第四: 税額（10円未満四捨五入）
    def tax_for(v, b)
      row = lookup(v.brackets, b)
      Rounding.half_up_to_ten(BigDecimal(row.fetch(:rate)) * b - row.fetch(:sub))
    end

    # upto（以下）で区切られた表から該当行を返す。upto: null は上限なし。
    def lookup(rows, amount)
      rows.find { |r| r[:upto].nil? || amount <= r[:upto] } or raise Error, "該当する区分がありません: #{amount}"
    end
  end
end
