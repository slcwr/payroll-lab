module Types
  class CompanyType < BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :employees_count, Int, null: false

    def employees_count = object.employees.count
  end
end
