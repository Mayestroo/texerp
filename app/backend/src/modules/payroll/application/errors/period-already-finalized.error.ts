export class PeriodAlreadyFinalizedError extends Error {
  constructor() {
    super('Payroll period is already finalized');
  }
}
