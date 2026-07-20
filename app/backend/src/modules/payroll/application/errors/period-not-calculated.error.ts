export class PeriodNotCalculatedError extends Error {
  constructor(public readonly current_status: string) {
    super('Payroll period has not been calculated yet');
  }
}
