/// Decides whether a sync failure can be resolved automatically.
///
/// Most validation errors are permanent because retrying them will never
/// succeed without user intervention. The only soft success case is an
/// idempotent replay where the server has already processed the mutation.
class ConflictResolver {
  /// Returns `true` if the conflict is resolved locally and no further retry
  /// is needed, or `false` if the item should be treated as a permanent failure.
  Future<bool> resolve({
    required String localId,
    String? errorCode,
    String? errorMessage,
  }) async {
    switch (errorCode) {
      case 'DATE_OUT_OF_WINDOW':
      case 'NO_FOREMAN_ASSIGNED':
      case 'OPERATION_INACTIVE':
      case 'OPERATION_NOT_FOUND':
        // Permanent failures — cannot retry.
        return false;
      case 'DUPLICATE_ENTRY':
        // Could check whether the existing entry matches, but for the MVP
        // this is treated as a permanent failure surfaced to the user.
        return false;
      case 'IDEMPOTENT_REPLAY':
        // Already processed by the server — treat as success.
        return true;
      default:
        // Unknown errors are not auto-resolved; they remain failed so the
        // user can inspect the message rather than retrying indefinitely.
        return false;
    }
  }
}
