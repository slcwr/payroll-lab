import { gql } from "@apollo/client";

export const PAYROLL_RUN_FIELDS = gql`
  fragment PayrollRunFields on PayrollRun {
    id
    yearMonth
    paymentDate
    status
    employeesCount
    grossTotal
    deductionsTotal
    netTotal
    progress
    calculatedAt
    confirmedAt
    errorMessage
  }
`;

export const PAYROLL_RUNS = gql`
  ${PAYROLL_RUN_FIELDS}
  query PayrollRuns {
    payrollRuns {
      ...PayrollRunFields
    }
  }
`;

export const PAYROLL_RUN_DETAIL = gql`
  ${PAYROLL_RUN_FIELDS}
  query PayrollRunDetail($id: ID!, $flag: PayslipFlagEnum, $query: String, $after: String) {
    payrollRun(id: $id) {
      ...PayrollRunFields
      flagCounts {
        flag
        count
      }
      payslips(first: 30, after: $after, flag: $flag, query: $query) {
        nodes {
          id
          grossPay
          totalDeductions
          netPay
          flags
          employee {
            id
            code
            name
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
`;

const LINE_FIELDS = gql`
  fragment PayslipLineFields on PayslipLine {
    code
    name
    category
    amount
    taxable
    basis
  }
`;

export const PAYSLIP = gql`
  ${LINE_FIELDS}
  query Payslip($id: ID!) {
    payslip(id: $id) {
      id
      grossPay
      taxablePay
      totalDeductions
      netPay
      flags
      warnings
      employee {
        id
        code
        name
        birthDate
        hiredOn
        retiredOn
      }
      payrollRun {
        id
        yearMonth
        paymentDate
        status
      }
      earnings {
        ...PayslipLineFields
      }
      deductions {
        ...PayslipLineFields
      }
    }
  }
`;

export const CREATE_PAYROLL_RUN = gql`
  ${PAYROLL_RUN_FIELDS}
  mutation CreatePayrollRun($yearMonth: String!, $paymentDate: ISO8601Date!) {
    createPayrollRun(input: { yearMonth: $yearMonth, paymentDate: $paymentDate }) {
      payrollRun {
        ...PayrollRunFields
      }
      errors
    }
  }
`;

export const CALCULATE_PAYROLL_RUN = gql`
  ${PAYROLL_RUN_FIELDS}
  mutation CalculatePayrollRun($id: ID!) {
    calculatePayrollRun(input: { id: $id }) {
      payrollRun {
        ...PayrollRunFields
      }
      errors
    }
  }
`;

export const CONFIRM_PAYROLL_RUN = gql`
  ${PAYROLL_RUN_FIELDS}
  mutation ConfirmPayrollRun($id: ID!) {
    confirmPayrollRun(input: { id: $id }) {
      payrollRun {
        ...PayrollRunFields
      }
      errors
    }
  }
`;
