export class ForemanNotAssignedError extends Error {
  constructor() {
    super('Foreman is not assigned to this worker');
  }
}
