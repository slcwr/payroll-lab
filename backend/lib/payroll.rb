# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"
require "date"
require "yaml"

# 給与計算のドメイン層。
#
# Rails（ActiveRecord）には依存させず、純粋な Ruby オブジェクトだけで計算を完結させる。
# - 計算ロジックを DB やフレームワークから切り離し、単体テストを高速・網羅的に書けるようにする
# - 法改正で変わる料率・税額表は config/payroll/*.yml に「適用開始日つきのデータ」として持たせ、
#   コードを変えずに改正へ追従できるようにする
module Payroll
  class Error < StandardError; end

  # Zeitwerk（Rails）配下では自動読み込みされるが、
  # Rails を起動しない単体テストからも使えるよう明示的に require できるようにしておく。
  def self.require_all!
    %w[
      rounding format versioned money_line inputs rate_table withholding_tax_table
      eligibility steps/earnings steps/social_insurance steps/employment_insurance
      steps/income_tax steps/resident_tax result calculator
    ].each { |f| require_relative "payroll/#{f}" }
  end

  def self.config_dir
    File.expand_path("../config/payroll", __dir__)
  end
end
