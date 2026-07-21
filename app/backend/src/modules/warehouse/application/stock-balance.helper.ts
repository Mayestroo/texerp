export const stockBalanceSumCase = `
  SUM(
    CASE
      WHEN type IN ('RECEIPT', 'CORRECTION_POSITIVE') THEN quantity
      WHEN type IN ('ISSUANCE', 'CORRECTION_NEGATIVE') THEN -quantity
    END
  )
`;
