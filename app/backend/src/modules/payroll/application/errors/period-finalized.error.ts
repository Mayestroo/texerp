export class PeriodFinalizedError extends Error {
  constructor() {
    super('Cannot modify a finalized payroll period');
  }
}
