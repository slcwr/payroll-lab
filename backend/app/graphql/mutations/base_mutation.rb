module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject

    # 業務エラー（バリデーション・状態遷移）は GraphQL のエラーではなく、ペイロードの errors で返す。
    # フロントは errors を画面に表示し、システムエラーとは扱いを分けられる。
    field :errors, [String], null: false

    private

    def current_company = context.fetch(:current_company)

    def find_run(id) = current_company.payroll_runs.find(id)

    def failure(*messages, **payload) = { errors: messages.flatten, **payload }
  end
end
