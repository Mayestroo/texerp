export class EmptyUpdateError extends Error {
  constructor() {
    super('No update fields provided');
    this.name = EmptyUpdateError.name;
  }
}
