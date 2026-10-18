# 給与計算ドメイン層（lib/payroll）を読み込み、料率表を起動時に検証する。
# 料率ファイルの書き間違い（適用開始日の重複など）はリクエスト時ではなく起動時に失敗させる。
require Rails.root.join("lib/payroll").to_s
Payroll.require_all!

Rails.application.config.after_initialize do
  Payroll::RateTable.default
  Payroll::WithholdingTaxTable.default
end
