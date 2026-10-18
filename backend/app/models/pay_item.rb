class PayItem < ApplicationRecord
  belongs_to :company
  has_many :employee_allowances, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: { scope: :company_id }, format: { with: /\A[A-Z0-9_]+\z/ }
  validates :name, presence: true
end
