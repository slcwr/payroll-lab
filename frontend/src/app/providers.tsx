"use client";

import { ApolloProvider } from "@apollo/client";
import { type ReactNode, useEffect, useState } from "react";
import { IntlProvider, ThemeProvider, createTheme } from "smarthr-ui";
import { createApolloClient } from "@/lib/apollo";

const theme = createTheme();
const mocking = process.env.NEXT_PUBLIC_API_MOCKING === "enabled";

export function Providers({ children }: { children: ReactNode }) {
  const [client] = useState(createApolloClient);
  // モックモードでは Service Worker の起動を待ってから画面を描く（最初のリクエストを取りこぼさない）
  const [ready, setReady] = useState(!mocking);

  useEffect(() => {
    if (!mocking) return;
    void import("@/mocks/browser").then(({ startMocking }) => startMocking()).then(() => setReady(true));
  }, []);

  return (
    <IntlProvider locale="ja">
      <ThemeProvider theme={theme}>
        <ApolloProvider client={client}>{ready ? children : null}</ApolloProvider>
      </ThemeProvider>
    </IntlProvider>
  );
}
