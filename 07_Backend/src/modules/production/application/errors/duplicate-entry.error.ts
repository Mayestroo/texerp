export class DuplicateEntryError extends Error {
  constructor(public readonly existing_entry_id: string) {
    super(`Duplicate production entry: ${existing_entry_id}`);
  }
}
