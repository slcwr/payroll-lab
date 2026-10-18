class CreatePayrollRunsAndPayslips < ActiveRecord::Migration[8.0]
  def change
    create_table :payroll_runs do |t|
      t.references :company, null: false, foreign_key: true
      t.string :year_month, null: false, limit: 7
      t.date :payment_date, null: false
      t.string :status, null: false, default: "draft"
      # Cloud Run Jobs の並列タスク数と完了数。最後に終わったタスクが集計して calculated にする
      t.integer :shard_count, null: false, default: 1
      t.integer :completed_shards, null: false, default: 0
      t.integer :employees_count, null: false, default: 0
      t.bigint :gross_total, null: false, default: 0
      t.bigint :deductions_total, null: false, default: 0
      t.bigint :net_total, null: false, default: 0
      t.datetime :started_at
      t.datetime :calculated_at
      t.datetime :confirmed_at
      t.text :error_message
      t.timestamps
      t.index %i[company_id year_month], unique: true
    end

    create_table :payslips do |t|
      t.references :payroll_run, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :employee, null: false, foreign_key: true
      t.integer :gross_pay, null: false
      t.integer :taxable_pay, null: false
      t.integer :total_deductions, null: false
      t.integer :net_pay, null: false
      t.string :flags, array: true, null: false, default: []
      t.jsonb :warnings, null: false, default: []
      t.timestamps
      t.index %i[payroll_run_id employee_id], unique: true
      t.index :flags, using: :gin
    end

    # 明細行。数万人 × 数十〜100項目で月数百万行になるため、計算時は insert_all でまとめて書き込む
    create_table :payslip_lines do |t|
      t.references :payslip, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.string :category, null: false # earning / deduction
      t.integer :amount, null: false
      t.boolean :taxable, null: false, default: false
      t.text :basis
    end
  end
end
