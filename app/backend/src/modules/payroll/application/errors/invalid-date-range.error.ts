export class InvalidDateRangeError extends Error {
  constructor() {
    super('Invalid date range: start_date must be before end_date');
  }
}
