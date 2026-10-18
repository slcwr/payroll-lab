import type { Metadata } from "next";
import type { ReactNode } from "react";
import "smarthr-ui/smarthr-ui.css";
import "./globals.css";
import { AppShell } from "@/components/AppShell";
import { Providers } from "./providers";

export const metadata: Metadata = {
  title: "給与計算ラボ",
  description: "データ入力レス給与計算の学習用アプリ",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ja">
      <body>
        <Providers>
          <AppShell>{children}</AppShell>
        </Providers>
      </body>
    </html>
  );
}
