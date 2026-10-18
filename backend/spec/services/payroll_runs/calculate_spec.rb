require "rails_helper"

RSpec.describe PayrollRuns::Calculate do
  let(:company) { create(:company) }
  let(:run) { create(:payroll_run, company: company) }
  let!(:employee) { create(:employee, company: company) }

  before do
    position = create(:pay_item, company: company, code: "POSITION", name: "役職手当")
    create(:employee_allowance, employee: employee, pay_item: position, amount: 20_000)
    create(:attendance_summary, employee: employee, overtime_minutes: 600)
    run.start_calculation!
  end

  it "明細と明細行を保存し、計算済みにする" do
    described_class.call(run)
    run.reload

    expect(run).to be_calculated
    expect(run.employees_count).to eq 1
    slip = run.payslips.sole
    expect(slip.lines.pluck(:code)).to include("BASE", "ALW_POSITION", "OVERTIME", "HEALTH", "INCOME_TAX")
    expect(run.gross_total).to eq slip.gross_pay
  end

  it "再計算しても明細が重複しない（冪等）" do
    lines = -> { PayslipLine.joins(:payslip).where(payslips: { payroll_run_id: run.id }).count }
    described_class.call(run)
    first = lines.call

    run.start_calculation!
    described_class.call(run)

    expect(run.payslips.count).to eq 1
    expect(lines.call).to eq first
  end

  it "期間より前に退職した従業員は対象外" do
    create(:employee, company: company, retired_on: Date.new(2026, 9, 30))
    described_class.call(run)
    expect(run.reload.employees_count).to eq 1
  end

  it "従業員を分割して並列計算し、最後のタスクが集計する" do
    create_list(:employee, 3, company: company)
    run.start_calculation!(shard_count: 2)

    described_class.call(run, shard_index: 0, shard_count: 2)
    expect(run.reload).to be_calculating

    described_class.call(run, shard_index: 1, shard_count: 2)
    expect(run.reload).to be_calculated
    expect(run.employees_count).to eq 4
  end

  it "N+1 を起こさない（従業員数が増えてもクエリ数がほぼ一定）" do
    count_queries = lambda do
      n = 0
      callback = ->(*, payload) { n += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { described_class.call(run) }
      n
    end

    run.start_calculation!
    few = count_queries.call
    create_list(:employee, 20, company: company)
    run.start_calculation!
    many = count_queries.call

    expect(many - few).to be <= 2
  end

  it "確定済みの給与計算は再計算できない" do
    described_class.call(run)
    run.reload.confirm!
    expect { run.start_calculation! }.to raise_error(PayrollRun::InvalidTransition)
  end
end
