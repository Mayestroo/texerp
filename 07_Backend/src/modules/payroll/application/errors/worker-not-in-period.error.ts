export class WorkerNotInPeriodError extends Error {
  constructor() {
    super('Worker is not part of this payroll period');
  }
}
