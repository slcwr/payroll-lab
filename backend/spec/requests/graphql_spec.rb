require "rails_helper"

RSpec.describe "GraphQL API" do
  let!(:company) { create(:company) }

  def graphql(query, variables = {})
    post "/graphql", params: { query: query, variables: variables }, as: :json
    JSON.parse(response.body)
  end

  describe "給与計算の作成 → 計算 → 確定" do
    it "一連の流れを実行できる" do
      create(:employee, company: company)

      created = graphql(<<~GQL, { input: { yearMonth: "2026-10", paymentDate: "2026-11-25" } })
        mutation($input: CreatePayrollRunInput!) {
          createPayrollRun(input: $input) { payrollRun { id status } errors }
        }
      GQL
      id = created.dig("data", "createPayrollRun", "payrollRun", "id")
      expect(created.dig("data", "createPayrollRun", "payrollRun", "status")).to eq "DRAFT"

      perform_enqueued_jobs do
        graphql("mutation($id: ID!) { calculatePayrollRun(input: { id: $id }) { errors } }", { id: id })
      end

      detail = graphql(<<~GQL, { id: id })
        query($id: ID!) {
          payrollRun(id: $id) {
            status employeesCount grossTotal
            payslips(first: 10) { nodes { netPay employee { name } earnings { code amount basis } } }
          }
        }
      GQL
      run = detail.dig("data", "payrollRun")
      expect(run["status"]).to eq "CALCULATED"
      expect(run["employeesCount"]).to eq 1
      expect(run["grossTotal"]).to be_a(String) # BigInt は文字列で返る
      expect(run.dig("payslips", "nodes", 0, "earnings", 0, "code")).to eq "BASE"

      confirmed = graphql("mutation($id: ID!) { confirmPayrollRun(input: { id: $id }) { payrollRun { status } errors } }", { id: id })
      expect(confirmed.dig("data", "confirmPayrollRun", "payrollRun", "status")).to eq "CONFIRMED"

      again = graphql("mutation($id: ID!) { calculatePayrollRun(input: { id: $id }) { errors } }", { id: id })
      expect(again.dig("data", "calculatePayrollRun", "errors")).to include(match(/確定済み/))
    end
  end

  describe "バリデーションエラーは errors で返す" do
    it "同じ月の給与計算は作れない" do
      create(:payroll_run, company: company, year_month: "2026-10")
      res = graphql(<<~GQL)
        mutation { createPayrollRun(input: { yearMonth: "2026-10", paymentDate: "2026-11-25" }) { payrollRun { id } errors } }
      GQL
      expect(res.dig("data", "createPayrollRun", "errors")).not_to be_empty
      expect(res["errors"]).to be_nil
    end
  end

  describe "勤怠の取り込み" do
    it "従業員番号で突き合わせて upsert する" do
      emp = create(:employee, company: company, code: "E1")
      query = <<~GQL
        mutation($items: [AttendanceSummaryInput!]!) {
          importAttendanceSummaries(input: { yearMonth: "2026-10", items: $items }) { importedCount unknownEmployeeCodes errors }
        }
      GQL

      res = graphql(query, { items: [{ employeeCode: "E1", overtimeMinutes: 120 }, { employeeCode: "NOPE" }] })
      expect(res.dig("data", "importAttendanceSummaries")).to include("importedCount" => 1, "unknownEmployeeCodes" => ["NOPE"])

      graphql(query, { items: [{ employeeCode: "E1", overtimeMinutes: 180 }] })
      expect(emp.attendance_summaries.sole.overtime_minutes).to eq 180
    end
  end

  describe "テナント分離" do
    it "他社の明細は参照できない" do
      other = create(:company, name: "他社")
      run = create(:payroll_run, company: other)
      slip = run.payslips.create!(employee: create(:employee, company: other), gross_pay: 1, taxable_pay: 1,
                                  total_deductions: 0, net_pay: 1)

      res = graphql("query($id: ID!) { payslip(id: $id) { id } }", { id: slip.id })
      expect(res.dig("data", "payslip")).to be_nil
      expect(res["errors"].first["message"]).to match(/見つかりません/)
    end
  end
end
