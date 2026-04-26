import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final _log = Logger('SyncQueueService');
const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class SyncQueueItem {
  final String id;
  final String table;
  final String operation; // 'insert' | 'update' | 'delete'
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;
  String? lastError;
  String status; // 'pending' | 'processing' | 'completed' | 'failed'

  SyncQueueItem({
    required this.id,
    required this.table,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'operation': operation,
        'data': data,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'last_error': lastError,
        'status': status,
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        id: json['id'] as String,
        table: json['table'] as String,
        operation: json['operation'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        createdAt: DateTime.parse(json['created_at'] as String),
        retryCount: json['retry_count'] as int? ?? 0,
        lastError: json['last_error'] as String?,
        status: json['status'] as String? ?? 'pending',
      );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class SyncQueueService {
  static const _boxName = 'dogquest_sync_queue';
  static const _maxRetries = 5;

  /// Base delay in milliseconds for exponential backoff (1s, 2s, 4s, 8s, 16s).
  static const _baseDelayMs = 1000;

  late Box _box;
  Timer? _periodicTimer;
  bool _processing = false;

  // ---- Initialisation ------------------------------------------------------

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _log.info('SyncQueueService initialised – $pendingCount pending, '
        '$failedCount failed items in queue');
  }

  // ---- Public getters ------------------------------------------------------

  int get pendingCount => _allItems
      .where((i) => i.status == 'pending' || i.status == 'processing')
      .length;

  int get failedCount => _allItems.where((i) => i.status == 'failed').length;

  List<SyncQueueItem> get allItems => _allItems;

  // ---- Enqueue -------------------------------------------------------------

  /// Add a new sync operation to the queue.
  Future<void> enqueue({
    required String table,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    assert(
      operation == 'insert' || operation == 'update' || operation == 'delete',
      'operation must be insert, update, or delete',
    );

    final item = SyncQueueItem(
      id: _uuid.v4(),
      table: table,
      operation: operation,
      data: data,
      createdAt: DateTime.now(),
    );

    await _box.put(item.id, jsonEncode(item.toJson()));
    _log.fine('Enqueued $operation on $table (${item.id})');
  }

  // ---- Process queue -------------------------------------------------------

  /// Process all pending items in FIFO order (oldest first).
  ///
  /// Skips items whose next retry time has not yet arrived.
  Future<void> processQueue() async {
    if (_processing) {
      _log.fine('Queue processing already in progress — skipping');
      return;
    }
    _processing = true;

    try {
      final pending = _allItems
          .where((i) => i.status == 'pending' || i.status == 'processing')
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (pending.isEmpty) {
        _log.fine('Queue empty — nothing to process');
        return;
      }

      _log.info('Processing ${pending.length} queued sync items');
      final client = Supabase.instance.client;

      for (final item in pending) {
        // Check exponential backoff delay
        if (item.retryCount > 0) {
          final delayMs = _baseDelayMs * pow(2, item.retryCount - 1);
          final nextRetry =
              item.createdAt.add(Duration(milliseconds: delayMs.toInt()));
          if (DateTime.now().isBefore(nextRetry)) {
            _log.fine('Skipping ${item.id} — next retry at $nextRetry');
            continue;
          }
        }

        // Mark as processing
        item.status = 'processing';
        await _persist(item);

        try {
          switch (item.operation) {
            case 'insert':
              await client.from(item.table).insert(item.data);
              break;
            case 'update':
              await client
                  .from(item.table)
                  .update(item.data)
                  .eq('id', item.data['id']);
              break;
            case 'delete':
              await client.from(item.table).delete().eq('id', item.data['id']);
              break;
          }

          // Success — remove from queue
          await _box.delete(item.id);
          _log.info('Synced ${item.operation} on ${item.table} (${item.id})');
        } catch (e) {
          item.retryCount++;
          item.lastError = e.toString();

          if (item.retryCount >= _maxRetries) {
            item.status = 'failed';
            _log.warning(
              'Sync item ${item.id} failed after $_maxRetries retries: $e',
            );
            _logFailureToAnalytics(item);
          } else {
            item.status = 'pending';
            final nextDelay = _baseDelayMs * pow(2, item.retryCount - 1);
            _log.info(
              'Retry ${item.retryCount}/$_maxRetries for ${item.id} — '
              'next attempt in ${nextDelay}ms',
            );
          }

          await _persist(item);
        }
      }
    } finally {
      _processing = false;
    }
  }

  // ---- Retry / clear -------------------------------------------------------

  /// Reset retry count on all failed items so they can be reprocessed.
  Future<void> retryFailed() async {
    final failed = _allItems.where((i) => i.status == 'failed').toList();
    for (final item in failed) {
      item.retryCount = 0;
      item.lastError = null;
      item.status = 'pending';
      await _persist(item);
    }
    _log.info('Reset ${failed.length} failed items for retry');
  }

  /// Remove all completed items from the queue.
  Future<void> clearCompleted() async {
    final completed = _allItems.where((i) => i.status == 'completed').toList();
    for (final item in completed) {
      await _box.delete(item.id);
    }
    _log.fine('Cleared ${completed.length} completed items');
  }

  // ---- Periodic sync -------------------------------------------------------

  /// Start a periodic timer that processes the queue every 5 minutes.
  void startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => processQueue(),
    );
    _log.info('Periodic sync started (every 5 minutes)');
  }

  /// Cancel the periodic sync timer.
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _log.info('Periodic sync stopped');
  }

  // ---- Dispose -------------------------------------------------------------

  void dispose() {
    stopPeriodicSync();
    _log.info('SyncQueueService disposed');
  }

  // ---- Private helpers -----------------------------------------------------

  List<SyncQueueItem> get _allItems {
    return _box.values.map((raw) {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      return SyncQueueItem.fromJson(json);
    }).toList();
  }

  Future<void> _persist(SyncQueueItem item) async {
    await _box.put(item.id, jsonEncode(item.toJson()));
  }

  void _logFailureToAnalytics(SyncQueueItem item) {
    // Best-effort analytics logging. In production this would forward to
    // Firebase Analytics or Sentry. For now we rely on the Logger output.
    _log.severe(
      'SYNC_FAILURE: table=${item.table} op=${item.operation} '
      'id=${item.id} error=${item.lastError}',
    );
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider — must be overridden after Hive init
// ---------------------------------------------------------------------------

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  throw UnimplementedError(
    'syncQueueServiceProvider must be overridden after Hive init',
  );
});
