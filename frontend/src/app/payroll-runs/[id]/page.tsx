"use client";

import { useMutation, useQuery } from "@apollo/client";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import {
  Base,
  Button,
  Cluster,
  Heading,
  PageHeading,
  InformationPanel,
  Loader,
  SearchInput,
  Stack,
  Table,
  Td,
  Text,
  Th,
} from "smarthr-ui";
import { StatusBadge } from "@/components/StatusBadge";
import { CALCULATE_PAYROLL_RUN, CONFIRM_PAYROLL_RUN, PAYROLL_RUN_DETAIL } from "@/graphql/operations";
import type { MutationResult, PayrollRunDetailData, PayrollRunDetailVars, PayslipFlag } from "@/graphql/types";
import { FLAG_LABEL, dateLabel, yearMonthLabel, yen } from "@/lib/format";

export default function PayrollRunDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [flag, setFlag] = useState<PayslipFlag | null>(null);
  const [query, setQuery] = useState("");
  const [submittedQuery, setSubmittedQuery] = useState<string | null>(null);

  const { data, loading, error, fetchMore, startPolling, stopPolling, refetch } = useQuery<
    PayrollRunDetailData,
    PayrollRunDetailVars
  >(PAYROLL_RUN_DETAIL, { variables: { id, flag, query: submittedQuery }, notifyOnNetworkStatusChange: true });

  const run = data?.payrollRun;
  const calculating = run?.status === "CALCULATING";

  // 計算中は1秒ごとに進捗を取りにいき、終わったら止める
  useEffect(() => {
    if (calculating) startPolling(1000);
    else stopPolling();
    return () => stopPolling();
  }, [calculating, startPolling, stopPolling]);

  const [calculate, calc] = useMutation<MutationResult<"calculatePayrollRun">>(CALCULATE_PAYROLL_RUN, {
    variables: { id },
    onCompleted: () => void refetch(),
  });
  const [confirm, conf] = useMutation<MutationResult<"confirmPayrollRun">>(CONFIRM_PAYROLL_RUN, { variables: { id } });
  const mutationErrors = [
    ...(calc.data?.calculatePayrollRun.errors ?? []),
    ...(conf.data?.confirmPayrollRun.errors ?? []),
  ];

  if (error) {
    return (
      <InformationPanel type="error" heading="読み込みに失敗しました">
        {error.message}
      </InformationPanel>
    );
  }
  if (!run) return loading ? <Loader /> : <Text>給与計算が見つかりません</Text>;

  const canCalculate = run.status === "DRAFT" || run.status === "CALCULATED" || run.status === "FAILED";

  return (
    <Stack gap={1.5}>
      <Stack gap={0.5}>
        <Link href="/payroll-runs">← 給与計算の一覧</Link>
        <Cluster align="center" gap={1}>
          <PageHeading>{yearMonthLabel(run.yearMonth)}の給与計算</PageHeading>
          <StatusBadge status={run.status} />
        </Cluster>
        <Text color="TEXT_GREY">支給日 {dateLabel(run.paymentDate)}</Text>
      </Stack>

      <Cluster gap={1}>
        <Button variant={run.status === "DRAFT" ? "primary" : "secondary"} disabled={!canCalculate || calc.loading} onClick={() => void calculate()}>
          {run.status === "DRAFT" ? "計算する" : "再計算する"}
        </Button>
        <Button variant="primary" disabled={run.status !== "CALCULATED" || conf.loading} onClick={() => void confirm()}>
          確定する
        </Button>
      </Cluster>

      {mutationErrors.length > 0 && (
        <InformationPanel type="error" heading="実行できませんでした">
          {mutationErrors.join(" / ")}
        </InformationPanel>
      )}
      {run.status === "FAILED" && run.errorMessage && (
        <InformationPanel type="error" heading="計算に失敗しました">
          {run.errorMessage}
        </InformationPanel>
      )}
      {calculating && (
        <Base padding={1.5}>
          <Stack gap={0.5}>
            <Text>計算中… {Math.round(run.progress * 100)}%</Text>
            <div className="progressTrack">
              <div className="progressBar" style={{ width: `${run.progress * 100}%` }} />
            </div>
          </Stack>
        </Base>
      )}

      <div className="summaryGrid">
        <Summary label="対象人数" value={`${run.employeesCount.toLocaleString()}人`} />
        <Summary label="総支給額" value={yen(run.grossTotal)} />
        <Summary label="控除合計" value={yen(run.deductionsTotal)} />
        <Summary label="差引支給額" value={yen(run.netTotal)} />
      </div>

      {run.employeesCount > 0 && (
        <Base padding={1.5}>
          <Stack gap={1}>
            <Heading type="blockTitle">計算結果のチェック</Heading>
            <Cluster gap={0.5}>
              <Button size="S" variant={flag === null ? "primary" : "secondary"} onClick={() => setFlag(null)}>
                すべて
              </Button>
              {run.flagCounts.map(({ flag: f, count }) => (
                <Button key={f} size="S" variant={flag === f ? "primary" : "secondary"} onClick={() => setFlag(f)}>
                  {FLAG_LABEL[f]}（{count}）
                </Button>
              ))}
            </Cluster>
            <form
              onSubmit={(e) => {
                e.preventDefault();
                setSubmittedQuery(query || null);
              }}
            >
              <SearchInput
                name="query"
                tooltipMessage="氏名または従業員番号で検索"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                width="20em"
              />
            </form>

            <div className="tableScroll">
              <Table>
                <thead>
                  <tr>
                    <Th>従業員番号</Th>
                    <Th>氏名</Th>
                    <Th align="right">総支給額</Th>
                    <Th align="right">控除合計</Th>
                    <Th align="right">差引支給額</Th>
                    <Th>目印</Th>
                  </tr>
                </thead>
                <tbody>
                  {run.payslips.nodes.map((p) => (
                    <tr key={p.id}>
                      <Td>{p.employee.code}</Td>
                      <Td>
                        <Link href={`/payslips/${p.id}`}>{p.employee.name}</Link>
                      </Td>
                      <Td className="num">{yen(p.grossPay)}</Td>
                      <Td className="num">{yen(p.totalDeductions)}</Td>
                      <Td className={`num ${p.netPay < 0 ? "negative" : ""}`}>{yen(p.netPay)}</Td>
                      <Td>
                        <Text size="S" color="TEXT_GREY">
                          {p.flags.map((f) => FLAG_LABEL[f]).join("、")}
                        </Text>
                      </Td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            </div>
            {run.payslips.pageInfo.hasNextPage && (
              <Button
                disabled={loading}
                onClick={() => void fetchMore({ variables: { after: run.payslips.pageInfo.endCursor } })}
              >
                さらに表示
              </Button>
            )}
          </Stack>
        </Base>
      )}
    </Stack>
  );
}

function Summary({ label, value }: { label: string; value: string }) {
  return (
    <Base padding={1}>
      <Stack gap={0.25}>
        <Text size="S" color="TEXT_GREY">
          {label}
        </Text>
        <span className="summaryValue">{value}</span>
      </Stack>
    </Base>
  );
}
