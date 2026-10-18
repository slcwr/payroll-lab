class CreateAttendanceSummaries < ActiveRecord::Migration[8.0]
  def change
    # 勤怠管理から連携される月次の集計値
    create_table :attendance_summaries do |t|
      t.references :employee, null: false, foreign_key: { on_delete: :cascade }
      t.string :year_month, null: false, limit: 7 # "2026-10"
      t.integer :overtime_minutes, null: false, default: 0
      t.integer :late_night_minutes, null: false, default: 0
      t.integer :legal_holiday_minutes, null: false, default: 0
      t.integer :absence_days, null: false, default: 0
      t.integer :late_early_minutes, null: false, default: 0
      t.string :source, null: false, default: "smarthr_attendance" # 連携元（自社勤怠 / 外部勤怠API など）
      t.timestamps
      t.index %i[employee_id year_month], unique: true
      t.index :year_month
    end
  end
end
