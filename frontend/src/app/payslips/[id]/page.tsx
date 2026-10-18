"use client";

import { useQuery } from "@apollo/client";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Base, Cluster, Heading, InformationPanel, PageHeading, Loader, Stack, Table, Td, Text, Th } from "smarthr-ui";
import { PAYSLIP } from "@/graphql/operations";
import type { PayslipData, PayslipLine } from "@/graphql/types";
import { FLAG_LABEL, dateLabel, yearMonthLabel, yen } from "@/lib/format";

export default function PayslipPage() {
  const { id } = useParams<{ id: string }>();
  const { data, loading, error } = useQuery<PayslipData>(PAYSLIP, { variables: { id } });

  if (error) {
    return (
      <InformationPanel type="error" heading="読み込みに失敗しました">
        {error.message}
      </InformationPanel>
    );
  }
  const slip = data?.payslip;
  if (!slip) return loading ? <Loader /> : <Text>明細が見つかりません</Text>;

  const { employee, payrollRun } = slip;

  return (
    <Stack gap={1.5}>
      <Stack gap={0.5}>
        <Link href={`/payroll-runs/${payrollRun.id}`}>← {yearMonthLabel(payrollRun.yearMonth)}の給与計算</Link>
        <PageHeading>
          {employee.name}（{employee.code}）
        </PageHeading>
        <Text color="TEXT_GREY">
          {yearMonthLabel(payrollRun.yearMonth)} ・ 支給日 {dateLabel(payrollRun.paymentDate)} ・ 入社日 {dateLabel(employee.hiredOn)}
          {employee.retiredOn && ` ・ 退職日 ${dateLabel(employee.retiredOn)}`}
        </Text>
        {slip.flags.length > 0 && (
          <Text size="S">{slip.flags.map((f) => FLAG_LABEL[f]).join("、")}</Text>
        )}
      </Stack>

      {slip.warnings.length > 0 && (
        <InformationPanel type="warning" heading="確認が必要です">
          <ul>
            {slip.warnings.map((w) => (
              <li key={w}>{w}</li>
            ))}
          </ul>
        </InformationPanel>
      )}

      <div className="summaryGrid">
        <Amount label="総支給額" value={slip.grossPay} />
        <Amount label="課税支給額" value={slip.taxablePay} />
        <Amount label="控除合計" value={slip.totalDeductions} />
        <Amount label="差引支給額" value={slip.netPay} />
      </div>

      <div className="lineGrid">
        <Lines title="支給" lines={slip.earnings} total={slip.grossPay} />
        <Lines title="控除" lines={slip.deductions} total={slip.totalDeductions} />
      </div>
    </Stack>
  );
}

function Amount({ label, value }: { label: string; value: number }) {
  return (
    <Base padding={1}>
      <Stack gap={0.25}>
        <Text size="S" color="TEXT_GREY">
          {label}
        </Text>
        <span className={`summaryValue ${value < 0 ? "negative" : ""}`}>{yen(value)}</span>
      </Stack>
    </Base>
  );
}

function Lines({ title, lines, total }: { title: string; lines: PayslipLine[]; total: number }) {
  return (
    <Base padding={1}>
      <Stack gap={0.5}>
        <Cluster justify="space-between">
          <Heading type="blockTitle">{title}</Heading>
          <Text weight="bold">{yen(total)}</Text>
        </Cluster>
        <Table>
          <thead>
            <tr>
              <Th>項目</Th>
              <Th align="right">金額</Th>
            </tr>
          </thead>
          <tbody>
            {lines.map((l, i) => (
              <tr key={`${l.code}-${i}`}>
                <Td>
                  <Stack gap={0.25}>
                    <span>
                      {l.name}
                      {l.category === "EARNING" && !l.taxable && <Text size="S" color="TEXT_GREY">（非課税）</Text>}
                    </span>
                    {l.basis && <span className="basis">{l.basis}</span>}
                  </Stack>
                </Td>
                <Td className={`num ${l.amount < 0 ? "negative" : ""}`}>{yen(l.amount)}</Td>
              </tr>
            ))}
          </tbody>
        </Table>
      </Stack>
    </Base>
  );
}
