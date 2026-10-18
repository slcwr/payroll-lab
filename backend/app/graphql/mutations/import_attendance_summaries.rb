module Mutations
  # 外部の勤怠システムから月次の勤怠集計を取り込む（勤怠 → 給与計算の連携）。
  # 同じ従業員・同じ月のデータは上書きするので、勤怠の修正後に何度送ってもよい（冪等）。
  class ImportAttendanceSummaries < BaseMutation
    MAX_ITEMS = 5_000
    VALUE_KEYS = %i[overtime_minutes late_night_minutes legal_holiday_minutes absence_days late_early_minutes].freeze

    argument :year_month, String
    argument :source, String, required: false, default_value: "external_api"
    argument :items, [Types::AttendanceSummaryInput]

    field :imported_count, Int, null: false
    field :unknown_employee_codes, [String], null: false

    def resolve(year_month:, source:, items:)
      error = validate(year_month, items)
      return failure(error, imported_count: 0, unknown_employee_codes: []) if error

      ids = current_company.employees.where(code: items.map(&:employee_code)).pluck(:code, :id).to_h
      now = Time.current
      rows = items.filter_map do |item|
        id = ids[item.employee_code] or next
        item.to_h.slice(*VALUE_KEYS).merge(employee_id: id, year_month: year_month, source: source,
                                           created_at: now, updated_at: now)
      end
      if rows.any?
        AttendanceSummary.upsert_all(rows, unique_by: %i[employee_id year_month],
                                           update_only: VALUE_KEYS + %i[source])
      end

      { imported_count: rows.size, unknown_employee_codes: items.map(&:employee_code).uniq - ids.keys, errors: [] }
    end

    private

    def validate(year_month, items)
      return "対象月の形式が正しくありません（例: 2026-10）" unless year_month.match?(AttendanceSummary::YEAR_MONTH_FORMAT)
      return "一度に送れるのは#{MAX_ITEMS}件までです" if items.size > MAX_ITEMS
      if current_company.payroll_runs.confirmed.exists?(year_month: year_month)
        return "#{year_month}の給与計算は確定済みのため勤怠を変更できません"
      end

      negative = items.select { |i| i.to_h.slice(*VALUE_KEYS).values.any?(&:negative?) }.map(&:employee_code)
      "マイナスの値があります: #{negative.join(', ')}" if negative.any?
    end
  end
end
