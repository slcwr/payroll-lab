module Types
  class PayslipLineType < BaseObject
    field :code, String, null: false
    field :name, String, null: false
    field :category, LineCategoryEnum, null: false
    field :amount, Int, null: false, description: "金額（円）。欠勤控除などはマイナスの支給"
    field :taxable, Boolean, null: false
    field :basis, String, description: "計算根拠"
  end
end
