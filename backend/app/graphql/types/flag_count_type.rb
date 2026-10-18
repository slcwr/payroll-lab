module Types
  class FlagCountType < BaseObject
    field :flag, PayslipFlagEnum, null: false
    field :count, Int, null: false
  end
end
