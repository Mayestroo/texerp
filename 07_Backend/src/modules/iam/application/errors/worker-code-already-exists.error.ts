export class WorkerCodeAlreadyExistsError extends Error {
  constructor() {
    super('Worker code already exists');
    this.name = WorkerCodeAlreadyExistsError.name;
  }
}
