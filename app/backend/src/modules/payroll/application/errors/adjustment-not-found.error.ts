export class AdjustmentNotFoundError extends Error {
  constructor() {
    super('Payroll adjustment not found');
  }
}
