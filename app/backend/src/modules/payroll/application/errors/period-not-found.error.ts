export class PeriodNotFoundError extends Error {
  constructor() {
    super('Payroll period not found');
  }
}
