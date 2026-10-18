import { StatusLabel } from "smarthr-ui";
import type { PayrollRunStatus } from "@/graphql/types";
import { STATUS_LABEL } from "@/lib/format";

export function StatusBadge({ status }: { status: PayrollRunStatus }) {
  const { label, type } = STATUS_LABEL[status];
  return <StatusLabel type={type}>{label}</StatusLabel>;
}
