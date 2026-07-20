export class PeriodNotDraftOrCalculatedError extends Error {
  constructor(public readonly current_status: string) {
    super('Payroll period must be in DRAFT or CALCULATED status');
  }
}
