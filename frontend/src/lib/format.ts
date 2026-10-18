import type { PayrollRunStatus, PayslipFlag } from "@/graphql/types";

const yenFormatter = new Intl.NumberFormat("ja-JP");

/** 金額（円）。BigInt は文字列で届くので文字列のまま桁区切りする（Number に変換すると精度が落ちうる） */
export function yen(value: number | string): string {
  if (typeof value === "number") return `${yenFormatter.format(value)}円`;
  const negative = value.startsWith("-");
  const digits = negative ? value.slice(1) : value;
  if (!/^\d+$/.test(digits)) throw new Error(`invalid amount: ${value}`);
  return `${negative ? "-" : ""}${digits.replace(/\B(?=(\d{3})+(?!\d))/g, ",")}円`;
}

/** "2026-10" → "2026年10月分" */
export function yearMonthLabel(yearMonth: string): string {
  const [y, m] = yearMonth.split("-");
  return `${y}年${Number(m)}月分`;
}

/** "2026-11-25" → "2026年11月25日" */
export function dateLabel(iso: string): string {
  const [y, m, d] = iso.slice(0, 10).split("-");
  return `${y}年${Number(m)}月${Number(d)}日`;
}

export const STATUS_LABEL: Record<PayrollRunStatus, { label: string; type: "grey" | "blue" | "green" | "red" | "warning" }> = {
  DRAFT: { label: "未計算", type: "grey" },
  CALCULATING: { label: "計算中", type: "blue" },
  CALCULATED: { label: "計算済み", type: "warning" },
  CONFIRMED: { label: "確定済み", type: "green" },
  FAILED: { label: "失敗", type: "red" },
};

export const FLAG_LABEL: Record<PayslipFlag, string> = {
  HIRED_IN_PERIOD: "期間中の入社者",
  RETIRED_IN_PERIOD: "期間中の退職者",
  NEGATIVE_NET: "差引支給額マイナス",
  AGE_40: "40歳到達",
  AGE_65: "65歳到達",
  AGE_70: "70歳到達",
  AGE_75: "75歳到達",
  HAS_WARNING: "警告あり",
};
