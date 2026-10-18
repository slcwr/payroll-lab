class CreateCompaniesAndEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :prefecture, null: false, default: "tokyo"
      t.string :employment_insurance_business, null: false, default: "general"
      t.string :social_insurance_collection, null: false, default: "next_month"
      t.decimal :monthly_scheduled_hours, precision: 5, scale: 2, null: false, default: 160
      t.decimal :monthly_scheduled_days, precision: 4, scale: 2, null: false, default: 20
      t.timestamps
    end

    # 固定的な手当の定義（会社ごとに増減できる給与項目）
    create_table :pay_items do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :taxable, null: false, default: true
      t.boolean :overtime_base, null: false, default: true # 割増賃金の算定基礎に含めるか
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index %i[company_id code], unique: true
    end

    # 労務管理（従業員DB）。給与計算はここを入力として「データ入力レス」で動く
    create_table :employees do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.date :birth_date, null: false
      t.date :hired_on, null: false
      t.date :retired_on
      t.integer :base_salary, null: false
      t.integer :standard_monthly_remuneration
      t.integer :commute_allowance, null: false, default: 0
      t.boolean :withholding_spouse, null: false, default: false
      t.integer :dependents_count, null: false, default: 0
      t.integer :resident_tax_monthly, null: false, default: 0
      t.boolean :social_insurance_enrolled, null: false, default: true
      t.boolean :employment_insurance_enrolled, null: false, default: true
      t.timestamps
      t.index %i[company_id code], unique: true
      t.index %i[company_id hired_on retired_on]
    end
    add_check_constraint :employees, "base_salary >= 0", name: "employees_base_salary_non_negative"
    add_check_constraint :employees, "dependents_count >= 0", name: "employees_dependents_non_negative"

    create_table :employee_allowances do |t|
      t.references :employee, null: false, foreign_key: { on_delete: :cascade }
      t.references :pay_item, null: false, foreign_key: true
      t.integer :amount, null: false
      t.timestamps
      t.index %i[employee_id pay_item_id], unique: true
    end
  end
end
