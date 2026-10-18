// API なしで画面を確認するための GraphQL モック（MSW）。
// 明細データ（fixtures/payslips.json）はバックエンドの本物の計算ロジックで生成している:
//   cd backend && ruby script/export_mock_payslips.rb ../frontend/src/mocks/fixtures/payslips.json
import { HttpResponse, delay, graphql } from "msw";
import type { FlagCount, PayrollRun, PayslipDetail, PayslipFlag } from "@/graphql/types";
import fixtures from "./fixtures/payslips.json";

type FixturePayslip = Omit<PayslipDetail, "payrollRun">;
const payslips = fixtures as FixturePayslip[];
const PAGE_SIZE = 30;
const FLAG_ORDER: PayslipFlag[] = [
  "HIRED_IN_PERIOD", "RETIRED_IN_PERIOD", "NEGATIVE_NET", "AGE_40", "AGE_65", "AGE_70", "AGE_75", "HAS_WARNING",
];

const sum = (key: "grossPay" | "totalDeductions" | "netPay") => String(payslips.reduce((s, p) => s + p[key], 0));

const runs: PayrollRun[] = [
  {
    id: "1", yearMonth: "2026-09", paymentDate: "2026-10-23", status: "CONFIRMED", employeesCount: payslips.length,
    grossTotal: sum("grossPay"), deductionsTotal: sum("totalDeductions"), netTotal: sum("netPay"),
    progress: 1, calculatedAt: "2026-10-15T10:00:00+09:00", confirmedAt: "2026-10-16T18:00:00+09:00", errorMessage: null,
  },
  {
    id: "2", yearMonth: "2026-10", paymentDate: "2026-11-25", status: "DRAFT", employeesCount: 0,
    grossTotal: "0", deductionsTotal: "0", netTotal: "0", progress: 0, calculatedAt: null, confirmedAt: null, errorMessage: null,
  },
];

const findRun = (id: string) => runs.find((r) => r.id === id);
const hasResults = (r: PayrollRun) => r.status === "CALCULATED" || r.status === "CONFIRMED";

function flagCounts(): FlagCount[] {
  const counts = new Map<PayslipFlag, number>();
  payslips.forEach((p) => p.flags.forEach((f) => counts.set(f, (counts.get(f) ?? 0) + 1)));
  // バックエンド（Payslip::FLAGS）と同じ並び順で返す
  return FLAG_ORDER.filter((f) => counts.has(f)).map((flag) => ({ flag, count: counts.get(flag)! }));
}

// 計算中の進捗を数秒かけて進める
function simulateCalculation(run: PayrollRun) {
  Object.assign(run, { status: "CALCULATING", progress: 0, employeesCount: 0 });
  let step = 0;
  const timer = setInterval(() => {
    step += 1;
    run.progress = step / 4;
    if (step < 4) return;
    clearInterval(timer);
    Object.assign(run, {
      status: "CALCULATED", employeesCount: payslips.length, calculatedAt: new Date().toISOString(),
      grossTotal: sum("grossPay"), deductionsTotal: sum("totalDeductions"), netTotal: sum("netPay"),
    });
  }, 700);
}

const withTypename = (run: PayrollRun) => ({ __typename: "PayrollRun", ...run });

export const handlers = [
  graphql.query("PayrollRuns", () =>
    HttpResponse.json({ data: { payrollRuns: [...runs].sort((a, b) => b.yearMonth.localeCompare(a.yearMonth)).map(withTypename) } }),
  ),

  graphql.query("PayrollRunDetail", async ({ variables }) => {
    await delay(150);
    const run = findRun(variables.id as string);
    if (!run) return HttpResponse.json({ data: { payrollRun: null } });

    const q = ((variables.query as string | null) ?? "").trim();
    const filtered = hasResults(run)
      ? payslips.filter(
          (p) =>
            (!variables.flag || p.flags.includes(variables.flag as PayslipFlag)) &&
            (!q || p.employee.name.includes(q) || p.employee.code.includes(q)),
        )
      : [];
    const offset = variables.after ? Number(atob(variables.after as string)) : 0;
    const page = filtered.slice(offset, offset + PAGE_SIZE);
    const end = offset + page.length;

    return HttpResponse.json({
      data: {
        payrollRun: {
          ...withTypename(run),
          flagCounts: hasResults(run) ? flagCounts() : [],
          payslips: {
            nodes: page.map((p) => ({
              __typename: "Payslip", id: p.id, grossPay: p.grossPay, totalDeductions: p.totalDeductions,
              netPay: p.netPay, flags: p.flags, employee: { __typename: "Employee", id: p.employee.id, code: p.employee.code, name: p.employee.name },
            })),
            // relayStylePagination がページをつなぐのに使う
            edges: page.map((p, i) => ({ cursor: btoa(String(offset + i + 1)), node: { __ref: `Payslip:${p.id}` } })),
            pageInfo: { hasNextPage: end < filtered.length, endCursor: btoa(String(end)), hasPreviousPage: offset > 0, startCursor: btoa(String(offset)) },
          },
        },
      },
    });
  }),

  graphql.query("Payslip", ({ variables }) => {
    const p = payslips.find((s) => s.id === variables.id);
    const run = runs.find((r) => r.yearMonth === "2026-10")!;
    return HttpResponse.json({
      // 実際の GraphQL サーバーと同じく __typename を付ける（Apollo のフラグメント解決に必要）
      data: {
        payslip: p
          ? {
              __typename: "Payslip",
              ...p,
              employee: { __typename: "Employee", ...p.employee },
              earnings: p.earnings.map((l) => ({ __typename: "PayslipLine", ...l })),
              deductions: p.deductions.map((l) => ({ __typename: "PayslipLine", ...l })),
              payrollRun: { __typename: "PayrollRun", id: run.id, yearMonth: run.yearMonth, paymentDate: run.paymentDate, status: run.status },
            }
          : null,
      },
    });
  }),

  graphql.mutation("CreatePayrollRun", ({ variables }) => {
    const yearMonth = variables.yearMonth as string;
    if (runs.some((r) => r.yearMonth === yearMonth)) {
      return HttpResponse.json({ data: { createPayrollRun: { payrollRun: null, errors: ["対象月はすでに存在します"] } } });
    }
    const run: PayrollRun = {
      id: String(runs.length + 1), yearMonth, paymentDate: variables.paymentDate as string, status: "DRAFT",
      employeesCount: 0, grossTotal: "0", deductionsTotal: "0", netTotal: "0", progress: 0,
      calculatedAt: null, confirmedAt: null, errorMessage: null,
    };
    runs.push(run);
    return HttpResponse.json({ data: { createPayrollRun: { payrollRun: withTypename(run), errors: [] } } });
  }),

  graphql.mutation("CalculatePayrollRun", ({ variables }) => {
    const run = findRun(variables.id as string)!;
    if (run.status === "CONFIRMED") {
      return HttpResponse.json({ data: { calculatePayrollRun: { payrollRun: withTypename(run), errors: ["確定済みの給与計算は再計算できません"] } } });
    }
    simulateCalculation(run);
    return HttpResponse.json({ data: { calculatePayrollRun: { payrollRun: withTypename(run), errors: [] } } });
  }),

  graphql.mutation("ConfirmPayrollRun", ({ variables }) => {
    const run = findRun(variables.id as string)!;
    if (run.status !== "CALCULATED") {
      return HttpResponse.json({ data: { confirmPayrollRun: { payrollRun: withTypename(run), errors: ["計算が完了していません"] } } });
    }
    Object.assign(run, { status: "CONFIRMED", confirmedAt: new Date().toISOString() });
    return HttpResponse.json({ data: { confirmPayrollRun: { payrollRun: withTypename(run), errors: [] } } });
  }),
];
