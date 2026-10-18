module Types
  class EmployeeType < BaseObject
    field :id, ID, null: false
    field :code, String, null: false
    field :name, String, null: false
    field :birth_date, GraphQL::Types::ISO8601Date, null: false
    field :hired_on, GraphQL::Types::ISO8601Date, null: false
    field :retired_on, GraphQL::Types::ISO8601Date
  end
end
