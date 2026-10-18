import { describe, expect, it } from "vitest";
import { dateLabel, yearMonthLabel, yen } from "./format";

describe("yen", () => {
  it("数値を桁区切りする", () => {
    expect(yen(1234567)).toBe("1,234,567円");
    expect(yen(-15000)).toBe("-15,000円");
    expect(yen(0)).toBe("0円");
  });

  it("BigInt の文字列は Number に変換せず桁区切りする（2^53 を超えても正確）", () => {
    expect(yen("12345678901234567890")).toBe("12,345,678,901,234,567,890円");
    expect(yen("-1000")).toBe("-1,000円");
  });

  it("数字以外は受け付けない", () => {
    expect(() => yen("12a")).toThrow();
  });
});

describe("日付の表示", () => {
  it("対象月", () => expect(yearMonthLabel("2026-04")).toBe("2026年4月分"));
  it("支給日", () => expect(dateLabel("2026-11-05")).toBe("2026年11月5日"));
});
