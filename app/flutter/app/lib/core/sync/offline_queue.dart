import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'package:texerp/core/storage/local_db.dart';

/// Lifecycle status of an offline queue item.
enum SyncStatus { pending, syncing, synced, failed }

String _syncStatusToString(SyncStatus status) {
  switch (status) {
    case SyncStatus.pending:
      return 'PENDING';
    case SyncStatus.syncing:
      return 'SYNCING';
    case SyncStatus.synced:
      return 'SYNCED';
    case SyncStatus.failed:
      return 'FAILED';
  }
}

SyncStatus _syncStatusFromString(String value) {
  switch (value) {
    case 'SYNCING':
      return SyncStatus.syncing;
    case 'SYNCED':
      return SyncStatus.synced;
    case 'FAILED':
      return SyncStatus.failed;
    case 'PENDING':
    default:
      return SyncStatus.pending;
  }
}

/// Generates a time-ordered UUIDv7 string using the current timestamp and
/// secure random bytes. Used as the local idempotency key for queued mutations.
String _generateUuidV7() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final timestampHex = timestamp.toRadixString(16).padLeft(12, '0');

  final random = Random.secure();
  final bytes = List<int>.generate(10, (_) => random.nextInt(256));

  // Set version (0111) in the first nibble of byte 6.
  bytes[0] = (bytes[0] & 0x0F) | 0x70;
  // Set variant (10) in the first two bits of byte 8.
  bytes[2] = (bytes[2] & 0x3F) | 0x80;

  final randomHex =
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  final hex = '$timestampHex$randomHex';
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// A single queued mutation stored locally until it can be synced.
class OfflineQueueItem {
  const OfflineQueueItem({
    required this.localId,
    required this.entityType,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.syncStatus,
    this.errorMsg,
    this.retryCount = 0,
    this.serverId,
  });

  final String localId;
  final String entityType;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final String? errorMsg;
  final int retryCount;
  final String? serverId;

  factory OfflineQueueItem.fromMap(Map<String, dynamic> map) {
    return OfflineQueueItem(
      localId: map['local_id'] as String,
      entityType: map['entity_type'] as String,
      operation: map['operation'] as String,
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: _syncStatusFromString(map['sync_status'] as String),
      errorMsg: map['error_msg'] as String?,
      retryCount: map['retry_count'] as int? ?? 0,
      serverId: map['server_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'entity_type': entityType,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': createdAt.toIso8601String(),
      'sync_status': _syncStatusToString(syncStatus),
      'error_msg': errorMsg,
      'retry_count': retryCount,
      'server_id': serverId,
    };
  }
}

/// Local persistence layer for the offline mutation queue.
class OfflineQueue {
  /// Adds a new mutation to the tail of the queue.
  Future<void> enqueue({
    required String entityType,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await LocalDb.database;
    final localId = _generateUuidV7();
    final now = DateTime.now();
    await db.insert('offline_queue', {
      'local_id': localId,
      'entity_type': entityType,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': now.toIso8601String(),
      'sync_status': 'PENDING',
      'retry_count': 0,
    });
  }

  /// Returns all items waiting to be synced, oldest first.
  Future<List<OfflineQueueItem>> getPending() async {
    final db = await LocalDb.database;
    final rows = await db.query(
      'offline_queue',
      where: 'sync_status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'created_at ASC',
    );
    return rows.map(OfflineQueueItem.fromMap).toList();
  }

  /// Marks an item as successfully synced with its server-side id.
  Future<void> markSynced(String localId, String? serverId) async {
    final db = await LocalDb.database;
    await db.update(
      'offline_queue',
      {'sync_status': 'SYNCED', 'server_id': serverId},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Marks an item as failed and increments its retry counter.
  Future<void> markFailed(String localId, String error) async {
    final db = await LocalDb.database;
    await db.rawUpdate(
      'UPDATE offline_queue '
      'SET sync_status = ?, error_msg = ?, retry_count = retry_count + 1 '
      'WHERE local_id = ?',
      ['FAILED', error, localId],
    );
  }

  /// Reverts an item to [SyncStatus.pending] so it can be retried.
  Future<void> markPending(String localId) async {
    final db = await LocalDb.database;
    await db.update(
      'offline_queue',
      {'sync_status': 'PENDING', 'error_msg': null},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Marks an item as currently being synced.
  Future<void> markSyncing(String localId) async {
    final db = await LocalDb.database;
    await db.update(
      'offline_queue',
      {'sync_status': 'SYNCING'},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Resets items that were left in SYNCING (e.g. after a crash) back to
  /// PENDING so they can be retried on the next sync run.
  Future<void> resetStaleSyncing() async {
    final db = await LocalDb.database;
    await db.update(
      'offline_queue',
      {'sync_status': 'PENDING'},
      where: 'sync_status = ?',
      whereArgs: ['SYNCING'],
    );
  }

  /// Returns the number of items still waiting to be synced.
  Future<int> getPendingCount() async {
    final db = await LocalDb.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM offline_queue WHERE sync_status = ?',
      ['PENDING'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
