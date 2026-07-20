export class CannotCreateDirectorError extends Error {
  constructor() {
    super('A Director cannot create another Director');
    this.name = 'CannotCreateDirectorError';
  }
}
