class Payslip < ApplicationRecord
  FLAGS = %w[hired_in_period retired_in_period negative_net age_40 age_65 age_70 age_75 has_warning].freeze

  belongs_to :payroll_run
  belongs_to :employee
  has_many :lines, -> { order(:position) }, class_name: "PayslipLine", dependent: :delete_all

  scope :flagged, ->(flag) { where("? = ANY(payslips.flags)", flag) }
  scope :search, lambda { |q|
    pattern = "%#{sanitize_sql_like(q)}%"
    joins(:employee).where("employees.name ILIKE :p OR employees.code ILIKE :p", p: pattern)
  }
end
