namespace :payroll do
  desc "給与計算を実行する（Cloud Run Jobs のタスクから呼ばれる）"
  task :calculate, [:payroll_run_id] => :environment do |_, args|
    run = PayrollRun.find(args.fetch(:payroll_run_id))
    # Cloud Run Jobs は各タスクに CLOUD_RUN_TASK_INDEX / CLOUD_RUN_TASK_COUNT を渡す
    index = ENV.fetch("CLOUD_RUN_TASK_INDEX", 0).to_i
    count = ENV.fetch("CLOUD_RUN_TASK_COUNT", run.shard_count).to_i
    n = PayrollRuns::Calculate.call(run, shard_index: index, shard_count: count)
    puts "payroll_run=#{run.id} shard=#{index}/#{count} employees=#{n}"
  end

  desc "計算性能を測る: bin/rails 'payroll:benchmark[10000]'"
  task :benchmark, [:employees] => :environment do |_, args|
    n = args.fetch(:employees, 10_000).to_i
    company = Company.create!(name: "ベンチマーク株式会社 #{Time.current.to_i}")
    puts "従業員 #{n} 人を作成中..."
    SeedData.create_employees(company, n, year_month: "2026-10", random: Random.new(1))

    run = company.payroll_runs.create!(year_month: "2026-10", payment_date: Date.new(2026, 11, 25))
    run.start_calculation!
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    PayrollRuns::Calculate.call(run)
    sec = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
    run.reload
    lines = PayslipLine.joins(:payslip).where(payslips: { payroll_run_id: run.id }).count
    puts format("%d人 / 明細行 %d行 / %.1f秒（%.0f人/秒）", run.employees_count, lines, sec, run.employees_count / sec)
  ensure
    # 外部キーの ON DELETE CASCADE で明細・手当・勤怠もまとめて消える
    company&.destroy! if ENV["KEEP"].blank?
  end
end
