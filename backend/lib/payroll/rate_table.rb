# frozen_string_literal: true

module Payroll
  # 社会保険・雇用保険の料率表（適用開始日つき）。
  # config/payroll/insurance_rates.yml を読み込む。
  class RateTable
    WelfarePension = Data.define(:rate, :standard_remuneration_cap)

    def self.load(path = File.join(Payroll.config_dir, "insurance_rates.yml"))
      new(YAML.safe_load_file(path, permitted_classes: [Date], symbolize_names: true))
    end

    def self.default
      @default ||= load
    end

    def initialize(data)
      @health = versioned(data.fetch(:health_insurance)) { |e| e.fetch(:rates).transform_keys(&:to_s).transform_values { d(_1) } }
      @nursing = versioned(data.fetch(:nursing_care)) { |e| d(e.fetch(:rate)) }
      @child_support = versioned(data.fetch(:child_support, [])) { |e| d(e.fetch(:rate)) }
      @pension = versioned(data.fetch(:welfare_pension)) do |e|
        WelfarePension.new(rate: d(e.fetch(:rate)), standard_remuneration_cap: e.fetch(:standard_remuneration_cap))
      end
      @employment = versioned(data.fetch(:employment_insurance)) { |e| e.fetch(:rates).transform_values { d(_1) } }
    end

    # 健康保険料率（労使合計）。協会けんぽは支部（都道府県）ごとに異なる。
    def health_insurance(month_start, prefecture:)
      rates = @health.at(month_start) or raise Error, "健康保険料率が未設定です: #{month_start}"
      rates.fetch(prefecture.to_s) { raise Error, "健康保険料率が未設定の支部です: #{prefecture}" }
    end

    # 介護保険料率（労使合計）。
    def nursing_care(month_start)
      @nursing.at(month_start) or raise Error, "介護保険料率が未設定です: #{month_start}"
    end

    # 子ども・子育て支援金の率（労使合計）。制度開始前は 0。
    def child_support(month_start)
      @child_support.at(month_start) || BigDecimal("0")
    end

    def welfare_pension(month_start)
      @pension.at(month_start) or raise Error, "厚生年金保険料率が未設定です: #{month_start}"
    end

    # 雇用保険料率（労働者負担分）。賃金締切日時点の率を使う。
    def employment_insurance(closing_date, business:)
      rates = @employment.at(closing_date) or raise Error, "雇用保険料率が未設定です: #{closing_date}"
      rates.fetch(business.to_sym) { raise Error, "雇用保険の事業区分が不正です: #{business}" }
    end

    private

    def versioned(entries)
      Versioned.new(entries.map { |e| { effective_from: e.fetch(:effective_from), value: yield(e) } })
    end

    def d(v) = BigDecimal(v.to_s)
  end
end
