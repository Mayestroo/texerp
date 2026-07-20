export class CalculationAlreadyRunningError extends Error {
  constructor() {
    super('Payroll calculation is already running for this period');
  }
}
