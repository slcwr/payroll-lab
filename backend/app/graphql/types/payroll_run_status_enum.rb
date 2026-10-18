module Types
  class PayrollRunStatusEnum < BaseEnum
    description "給与計算の状態"

    value "DRAFT", "未計算", value: "draft"
    value "CALCULATING", "計算中", value: "calculating"
    value "CALCULATED", "計算済み", value: "calculated"
    value "CONFIRMED", "確定済み", value: "confirmed"
    value "FAILED", "失敗", value: "failed"
  end
end
