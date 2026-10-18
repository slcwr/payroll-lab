class GraphqlController < ApplicationController
  def execute
    result = PayrollLabSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      operation_name: params[:operationName],
      context: { current_company: current_company }
    )
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?

    render json: { errors: [{ message: e.message, backtrace: e.backtrace.first(10) }], data: {} }, status: :internal_server_error
  end

  private

  # 学習用のため認証は省略し、最初の会社を操作対象にする。
  # 実運用ではログインユーザーの所属テナントから決め、すべてのクエリをテナントで絞る。
  def current_company
    @current_company ||= Company.order(:id).first!
  end

  def prepare_variables(variables)
    case variables
    when String then variables.present? ? JSON.parse(variables) : {}
    when Hash then variables
    when ActionController::Parameters then variables.to_unsafe_hash
    when nil then {}
    else raise ArgumentError, "Unexpected parameter: #{variables}"
    end
  end
end
