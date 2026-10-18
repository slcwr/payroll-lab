// GraphQL スキーマに対応する型。
// 実運用では graphql-codegen でスキーマから自動生成する（README 参照）。

export type PayrollRunStatus = "DRAFT" | "CALCULATING" | "CALCULATED" | "CONFIRMED" | "FAILED";

export type PayslipFlag =
  | "HIRED_IN_PERIOD"
  | "RETIRED_IN_PERIOD"
  | "NEGATIVE_NET"
  | "AGE_40"
  | "AGE_65"
  | "AGE_70"
  | "AGE_75"
  | "HAS_WARNING";

export type LineCategory = "EARNING" | "DEDUCTION";

export type Employee = {
  id: string;
  code: string;
  name: string;
  birthDate: string;
  hiredOn: string;
  retiredOn: string | null;
};

export type PayslipLine = {
  code: string;
  name: string;
  category: LineCategory;
  amount: number;
  taxable: boolean;
  basis: string | null;
};

export type PayslipSummary = {
  id: string;
  grossPay: number;
  totalDeductions: number;
  netPay: number;
  flags: PayslipFlag[];
  employee: Pick<Employee, "id" | "code" | "name">;
};

export type PayslipDetail = PayslipSummary & {
  taxablePay: number;
  warnings: string[];
  employee: Employee;
  earnings: PayslipLine[];
  deductions: PayslipLine[];
  payrollRun: Pick<PayrollRun, "id" | "yearMonth" | "paymentDate" | "status">;
};

export type FlagCount = { flag: PayslipFlag; count: number };

export type PayrollRun = {
  id: string;
  yearMonth: string;
  paymentDate: string;
  status: PayrollRunStatus;
  employeesCount: number;
  // BigInt は文字列で返る（Int の上限 約21億を超えうるため）
  grossTotal: string;
  deductionsTotal: string;
  netTotal: string;
  progress: number;
  calculatedAt: string | null;
  confirmedAt: string | null;
  errorMessage: string | null;
};

export type PageInfo = { hasNextPage: boolean; endCursor: string | null };

export type PayrollRunsData = { payrollRuns: PayrollRun[] };

export type PayrollRunDetailData = {
  payrollRun:
    | (PayrollRun & {
        flagCounts: FlagCount[];
        payslips: { nodes: PayslipSummary[]; pageInfo: PageInfo };
      })
    | null;
};
export type PayrollRunDetailVars = { id: string; flag?: PayslipFlag | null; query?: string | null; after?: string | null };

export type PayslipData = { payslip: PayslipDetail | null };

export type MutationResult<K extends string> = Record<K, { payrollRun: PayrollRun | null; errors: string[] }>;
