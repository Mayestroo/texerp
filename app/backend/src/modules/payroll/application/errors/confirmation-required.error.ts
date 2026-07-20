export class ConfirmationRequiredError extends Error {
  constructor() {
    super('Confirmation required to finalize payroll period');
  }
}
