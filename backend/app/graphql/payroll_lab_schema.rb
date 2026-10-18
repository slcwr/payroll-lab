class PayrollLabSchema < GraphQL::Schema
  query Types::QueryType
  mutation Types::MutationType

  # 明細一覧で従業員・明細行を取るときの N+1 をまとめて解消する
  use GraphQL::Dataloader

  # 重いクエリでサーバーを止めないための上限
  max_depth 12
  max_complexity 500
  default_max_page_size 100

  rescue_from(ActiveRecord::RecordNotFound) do |_err, _obj, _args, _ctx, field|
    raise GraphQL::ExecutionError, "#{field.type.unwrap.graphql_name} が見つかりません"
  end
end
