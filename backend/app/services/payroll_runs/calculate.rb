module PayrollRuns
  # 給与計算バッチの本体。
  #
  # 数万人規模でも月次の限られた時間で終わらせるための工夫:
  #   1. 従業員を BATCH_SIZE 件ずつ読み込み、メモリ使用量を一定に保つ
  #   2. 手当・勤怠はバッチ単位でまとめて読み込む（N+1 を起こさない）
  #   3. 計算はドメイン層の純粋関数で行い、DB には触れない
  #   4. 明細は insert_all でまとめて書き込む（1人ずつ INSERT しない）
  #   5. shard_index / shard_count で従業員を分割し、Cloud Run Jobs の複数タスクで並列実行できる
  #
  # 再計算しても同じ結果になるよう、書き込み前に同じ従業員の明細を削除する（冪等）。
  class Calculate
    BATCH_SIZE = 500

    def self.call(run, shard_index: 0, shard_count: 1)
      new(run, shard_index: shard_index, shard_count: shard_count).call
    end

    def initialize(run, shard_index:, shard_count:)
      @run = run
      @shard_index = shard_index
      @shard_count = shard_count
      @calculator = Payroll::Calculator.new(rules: run.company.work_rules)
      @period = run.period
    end

    def call
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      count = 0

      target_employees.in_batches(of: BATCH_SIZE) do |relation|
        employees = relation.includes(employee_allowances: :pay_item).to_a
        attendance = AttendanceSummary.where(employee_id: employees.map(&:id), year_month: @run.year_month)
                                      .index_by(&:employee_id)

        results = employees.map do |employee|
          [employee, @calculator.calculate(employee: employee.to_payroll_snapshot,
                                           attendance: attendance[employee.id]&.to_payroll_summary,
                                           period: @period)]
        end
        persist(results)
        count += results.size
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      Rails.logger.info(event: "payroll_run.shard_completed", payroll_run_id: @run.id, shard_index: @shard_index,
                        shard_count: @shard_count, employees: count, seconds: elapsed.round(2))
      @run.shard_completed!
      count
    rescue StandardError => e
      @run.fail!(e)
      raise
    end

    private

    def target_employees
      scope = @run.company.employees.active_during(@period.start_date, @period.end_date)
      scope = scope.where("employees.id % ? = ?", @shard_count, @shard_index) if @shard_count > 1
      scope
    end

    def persist(results)
      now = Time.current
      Payslip.transaction do
        # 再計算時は既存の明細を置き換える（payslip_lines は外部キーの ON DELETE CASCADE で消える）
        Payslip.where(payroll_run_id: @run.id, employee_id: results.map { _1.first.id }).delete_all

        rows = results.map do |employee, r|
          { payroll_run_id: @run.id, employee_id: employee.id, gross_pay: r.gross_pay, taxable_pay: r.taxable_pay,
            total_deductions: r.total_deductions, net_pay: r.net_pay, flags: r.flags, warnings: r.warnings,
            created_at: now, updated_at: now }
        end
        inserted = Payslip.insert_all!(rows, returning: %w[id employee_id])
        payslip_ids = inserted.to_a.to_h { [_1["employee_id"], _1["id"]] }

        lines = results.flat_map do |employee, r|
          r.lines.each_with_index.map do |line, i|
            { payslip_id: payslip_ids.fetch(employee.id), position: i, code: line.code, name: line.name,
              category: line.category.to_s, amount: line.amount, taxable: line.taxable, basis: line.basis }
          end
        end
        PayslipLine.insert_all!(lines) if lines.any?
      end
    end
  end
end
