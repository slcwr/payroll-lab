"use client";

import { useMutation, useQuery } from "@apollo/client";
import Link from "next/link";
import { useState } from "react";
import {
  Base,
  Button,
  Cluster,
  FormControl,
  Heading,
  PageHeading,
  InformationPanel,
  Input,
  Loader,
  Stack,
  Table,
  Td,
  Th,
} from "smarthr-ui";
import { StatusBadge } from "@/components/StatusBadge";
import { CREATE_PAYROLL_RUN, PAYROLL_RUNS } from "@/graphql/operations";
import type { MutationResult, PayrollRunsData } from "@/graphql/types";
import { dateLabel, yearMonthLabel, yen } from "@/lib/format";

export default function PayrollRunsPage() {
  const { data, loading, error } = useQuery<PayrollRunsData>(PAYROLL_RUNS);

  return (
    <Stack gap={1.5}>
      <PageHeading>給与計算</PageHeading>
      <CreateRunForm />
      {error && (
        <InformationPanel type="error" heading="読み込みに失敗しました">
          {error.message}
        </InformationPanel>
      )}
      {loading ? (
        <Loader />
      ) : (
        <Base>
          <div className="tableScroll">
            <Table>
              <thead>
                <tr>
                  <Th>対象月</Th>
                  <Th>支給日</Th>
                  <Th>状態</Th>
                  <Th align="right">人数</Th>
                  <Th align="right">総支給額</Th>
                  <Th align="right">差引支給額</Th>
                </tr>
              </thead>
              <tbody>
                {data?.payrollRuns.map((run) => (
                  <tr key={run.id}>
                    <Td>
                      <Link href={`/payroll-runs/${run.id}`}>{yearMonthLabel(run.yearMonth)}</Link>
                    </Td>
                    <Td>{dateLabel(run.paymentDate)}</Td>
                    <Td>
                      <StatusBadge status={run.status} />
                    </Td>
                    <Td className="num">{run.employeesCount.toLocaleString()}人</Td>
                    <Td className="num">{yen(run.grossTotal)}</Td>
                    <Td className="num">{yen(run.netTotal)}</Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          </div>
        </Base>
      )}
    </Stack>
  );
}

function CreateRunForm() {
  const [yearMonth, setYearMonth] = useState("");
  const [paymentDate, setPaymentDate] = useState("");
  const [create, { data, loading }] = useMutation<MutationResult<"createPayrollRun">>(CREATE_PAYROLL_RUN, {
    refetchQueries: [PAYROLL_RUNS],
  });
  const errors = data?.createPayrollRun.errors ?? [];

  return (
    <Base padding={1.5}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          void create({ variables: { yearMonth, paymentDate } });
        }}
      >
        <Stack gap={1}>
          <Heading type="blockTitle">給与計算を作成</Heading>
          <Cluster gap={1.5} align="flex-end">
            <FormControl label="対象月">
              <Input type="month" value={yearMonth} onChange={(e) => setYearMonth(e.target.value)} required />
            </FormControl>
            <FormControl label="支給日">
              <Input type="date" value={paymentDate} onChange={(e) => setPaymentDate(e.target.value)} required />
            </FormControl>
            <Button type="submit" variant="primary" disabled={loading}>
              作成
            </Button>
          </Cluster>
          {errors.length > 0 && (
            <InformationPanel type="error" heading="作成できませんでした">
              {errors.join(" / ")}
            </InformationPanel>
          )}
        </Stack>
      </form>
    </Base>
  );
}
