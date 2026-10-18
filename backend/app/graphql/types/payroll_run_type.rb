module Types
  class PayrollRunType < BaseObject
    field :id, ID, null: false
    field :year_month, String, null: false
    field :payment_date, GraphQL::Types::ISO8601Date, null: false
    field :status, PayrollRunStatusEnum, null: false
    field :employees_count, Int, null: false
    # 数万人分の合計は Int（32bit）の上限 約21億円を超えうるので BigInt（文字列で返る）にする
    field :gross_total, GraphQL::Types::BigInt, null: false
    field :deductions_total, GraphQL::Types::BigInt, null: false
    field :net_total, GraphQL::Types::BigInt, null: false
    field :progress, Float, null: false, description: "並列計算の進捗（0〜1）"
    field :calculated_at, GraphQL::Types::ISO8601DateTime
    field :confirmed_at, GraphQL::Types::ISO8601DateTime
    field :error_message, String
    field :flag_counts, [FlagCountType], null: false

    field :payslips, PayslipType.connection_type, null: false do
      argument :flag, PayslipFlagEnum, required: false
      argument :query, String, required: false, description: "氏名・従業員番号で検索"
    end

    def progress
      return 1.0 if object.calculated? || object.confirmed?
      return 0.0 unless object.calculating?

      object.completed_shards.fdiv(object.shard_count)
    end

    def flag_counts
      Payslip::FLAGS.filter_map do |flag|
        count = counts[flag].to_i
        { flag: flag, count: count } if count.positive?
      end
    end

    def payslips(flag: nil, query: nil)
      scope = object.payslips.order(:id)
      scope = scope.flagged(flag) if flag
      scope = scope.search(query) if query.present?
      scope
    end

    private

    def counts = @counts ||= object.flag_counts
  end
end
