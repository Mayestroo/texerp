export class PeriodOverlapError extends Error {
  constructor(public readonly existing_period_id: string) {
    super('Payroll period overlaps with existing period');
  }
}
