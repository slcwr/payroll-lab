module Types
  class PayslipFlagEnum < BaseEnum
    description "計算結果のチェックで絞り込むための目印"

    value "HIRED_IN_PERIOD", "期間中の入社者", value: "hired_in_period"
    value "RETIRED_IN_PERIOD", "期間中の退職者", value: "retired_in_period"
    value "NEGATIVE_NET", "差引支給額がマイナス", value: "negative_net"
    value "AGE_40", "40歳到達者（介護保険の開始）", value: "age_40"
    value "AGE_65", "65歳到達者（介護保険の終了）", value: "age_65"
    value "AGE_70", "70歳到達者（厚生年金の終了）", value: "age_70"
    value "AGE_75", "75歳到達者（健康保険の終了）", value: "age_75"
    value "HAS_WARNING", "警告あり", value: "has_warning"
  end
end
