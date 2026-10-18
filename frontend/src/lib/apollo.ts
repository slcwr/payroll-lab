import { ApolloClient, HttpLink, InMemoryCache } from "@apollo/client";
import { relayStylePagination } from "@apollo/client/utilities";

export function createApolloClient() {
  return new ApolloClient({
    link: new HttpLink({ uri: process.env.NEXT_PUBLIC_GRAPHQL_URL ?? "http://localhost:3000/graphql" }),
    cache: new InMemoryCache({
      typePolicies: {
        PayrollRun: {
          fields: {
            // 絞り込み条件ごとに別のリストとしてキャッシュし、「さらに表示」で末尾に連結する
            payslips: relayStylePagination(["flag", "query"]),
          },
        },
      },
    }),
  });
}
