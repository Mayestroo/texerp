export class EmptyPayrollPeriodUpdateError extends Error {
  constructor() {
    super('No fields to update');
  }
}
