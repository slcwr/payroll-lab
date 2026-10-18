# frozen_string_literal: true

module Payroll
  # 給与計算で登場する端数処理をまとめたモジュール。
  # 「どの金額をどのルールで丸めるか」は事故が起きやすいので、名前で意図が分かるようにする。
  module Rounding
    module_function

    HALF = BigDecimal("0.5")

    # 社会保険料・雇用保険料の被保険者負担分を給与から控除する場合の端数処理。
    # 50銭以下は切り捨て、50銭を超える場合は切り上げ（特約がない場合の原則）。
    def social_insurance(amount)
      d = to_d(amount)
      int = d.floor
      (d - int) > HALF ? int + 1 : int
    end

    # 割増賃金などで使う四捨五入（50銭未満切り捨て、50銭以上切り上げ）。
    def half_up(amount)
      to_d(amount).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def ceil(amount)
      to_d(amount).ceil.to_i
    end

    def floor(amount)
      to_d(amount).floor.to_i
    end

    # 源泉所得税（電算機計算の特例）: 10円未満の端数を四捨五入。
    def half_up_to_ten(amount)
      (to_d(amount) / 10).round(0, BigDecimal::ROUND_HALF_UP).to_i * 10
    end

    def to_d(value)
      case value
      when BigDecimal then value
      when Rational then value.to_d(30) # 日割り・時間換算は有理数のまま持ち、丸める直前に変換する
      else BigDecimal(value.to_s)
      end
    end
  end
end
