import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BackendSyncService {
  BackendSyncService({
    required Box<Map> pendingSyncBox,
  });

  /// Sync a newly identified dog to the backend collection.
  /// Returns server response or null if sync failed.
  /// When [isRetry] is true, failures will not re-enqueue to the pending sync queue.
  Future<Map<String, dynamic>?> syncDogToCollection(
    String dogName, {
    double confidence = 0.0,
    String source = 'ml',
    bool isRetry = false,
  }) async {
    // Backend not configured for DogQuest yet
    return null;
  }

  /// Fetch user profile from backend.
  Future<Map<String, dynamic>?> fetchProfile() async {
    // Backend not configured for DogQuest yet
    return null;
  }

  /// Fetch user collection from backend.
  Future<Map<String, dynamic>?> fetchCollection() async {
    // Backend not configured for DogQuest yet
    return null;
  }

  /// Attempt to flush all pending syncs.
  Future<void> flushPendingSyncs() async {
    // Backend not configured for DogQuest yet
    return;
  }
}

final backendSyncProvider = Provider<BackendSyncService>((ref) {
  throw UnimplementedError('backendSyncProvider must be overridden at startup');
});
