import Link from "next/link";
import type { ReactNode } from "react";

const mocking = process.env.NEXT_PUBLIC_API_MOCKING === "enabled";

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <>
      <header className="appHeader">
        <div className="appHeaderInner">
          <Link href="/payroll-runs" className="appName">
            給与計算ラボ
          </Link>
          {mocking && <span className="mockBadge">モックデータ</span>}
        </div>
      </header>
      <main className="page">{children}</main>
    </>
  );
}
