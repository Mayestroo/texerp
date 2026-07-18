export class BulkApprovePartialFailureError extends Error {
  constructor(
    readonly successful_ids: string[],
    readonly failed_ids: Array<{ entry_id: string; reason: string }>,
  ) {
    super('Bulk approve finished with partial failures');
  }
}
