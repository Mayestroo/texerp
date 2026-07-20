export class ExportNotFoundError extends Error {
  constructor() {
    super('Payroll export not found');
  }
}
