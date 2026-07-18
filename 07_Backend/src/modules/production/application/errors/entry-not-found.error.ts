export class EntryNotFoundError extends Error {
  constructor() {
    super('Production entry not found');
  }
}
