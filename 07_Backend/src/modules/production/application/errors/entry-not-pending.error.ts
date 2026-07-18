export class EntryNotPendingError extends Error {
  constructor() {
    super('Production entry is not in PENDING status');
  }
}
