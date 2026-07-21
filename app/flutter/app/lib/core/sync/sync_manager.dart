import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/core/sync/conflict_resolver.dart';
import 'package:texerp/core/sync/offline_queue.dart';

/// Result of a single item returned by the backend sync endpoint.
class SyncItemResult {
  const SyncItemResult({
    required this.localId,
    required this.status,
    this.serverId,
    this.errorCode,
    this.errorMessage,
  });

  final String localId;
  final String status;
  final String? serverId;
  final String? errorCode;
  final String? errorMessage;

  factory SyncItemResult.fromJson(Map<String, dynamic> json) {
    return SyncItemResult(
      localId: json['client_idempotency_key'] as String? ?? '',
      status: json['status'] as String? ?? 'REJECTED',
      serverId: json['entry_id'] as String?,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
    );
  }
}

/// Aggregate result of a sync run.
class SyncResult {
  const SyncResult({
    required this.total,
    required this.accepted,
    required this.rejected,
    required this.results,
  });

  final int total;
  final int accepted;
  final int rejected;
  final List<SyncItemResult> results;
}

/// Orchestrates sending queued offline mutations to the backend.
class SyncManager {
  SyncManager({
    required ApiClient apiClient,
    required OfflineQueue offlineQueue,
    required ConflictResolver conflictResolver,
  })  : _apiClient = apiClient,
        _offlineQueue = offlineQueue,
        _conflictResolver = conflictResolver;

  final ApiClient _apiClient;
  final OfflineQueue _offlineQueue;
  final ConflictResolver _conflictResolver;

  bool _isSyncing = false;

  /// Sends pending mutations to the server in batches of up to 100 items.
  ///
  /// Returns `null` when there is nothing to sync or when another sync is
  /// already in progress. Throws on network errors after reverting the batch
  /// to [SyncStatus.pending] so it can be retried later.
  Future<SyncResult?> syncPending() async {
    if (_isSyncing) return null;
    _isSyncing = true;

    try {
      await _offlineQueue.resetStaleSyncing();
      final pending = await _offlineQueue.getPending();
      if (pending.isEmpty) return null;

      final batch = pending.take(100).toList();
      for (final item in batch) {
        await _offlineQueue.markSyncing(item.localId);
      }

      final entries = batch
          .map(
            (item) => <String, dynamic>{
              'client_idempotency_key': item.localId,
              ...item.payload,
            },
          )
          .toList();

      try {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/production/sync',
          data: {'entries': entries},
        );

        final responseData = response.data;
        final data = (responseData?['data'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
        final rawResults = data['results'] as List<dynamic>? ?? <dynamic>[];
        final results = rawResults
            .map((r) => SyncItemResult.fromJson(r as Map<String, dynamic>))
            .toList();

        final resultIds = results.map((r) => r.localId).toSet();

        int acceptedCount = 0;
        int rejectedCount = 0;
        for (final result in results) {
          if (result.status == 'ACCEPTED') {
            await _offlineQueue.markSynced(result.localId, result.serverId);
            acceptedCount++;
          } else {
            final resolved = await _conflictResolver.resolve(
              localId: result.localId,
              errorCode: result.errorCode,
              errorMessage: result.errorMessage,
            );
            if (resolved) {
              await _offlineQueue.markSynced(result.localId, result.localId);
              acceptedCount++;
            } else {
              await _offlineQueue.markFailed(
                result.localId,
                result.errorMessage ?? 'Sync failed',
              );
              rejectedCount++;
            }
          }
        }

        // Any item in the batch that did not appear in the response is
        // treated as a permanent failure so it does not stay stuck in SYNCING.
        for (final item in batch) {
          if (!resultIds.contains(item.localId)) {
            await _offlineQueue.markFailed(
              item.localId,
              'Missing sync response',
            );
            rejectedCount++;
          }
        }

        return SyncResult(
          total: batch.length,
          accepted: acceptedCount,
          rejected: rejectedCount,
          results: results,
        );
      } catch (e) {
        // Network or unexpected error — revert the batch to pending so the
        // next sync attempt can retry it.
        for (final item in batch) {
          await _offlineQueue.markPending(item.localId);
        }
        rethrow;
      }
    } finally {
      _isSyncing = false;
    }
  }
}
