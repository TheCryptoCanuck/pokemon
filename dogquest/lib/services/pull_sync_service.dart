import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final pullSyncServiceProvider =
    Provider<PullSyncService>((ref) => PullSyncService());

/// Cloud-to-local pull sync service.
///
/// On app foreground (with an active Supabase session), pulls fresh data
/// from Supabase into local Hive cache. Each pull operation is independent;
/// a failure in one does not block the others.
class PullSyncService {
  PullSyncService();

  final _log = Logger('PullSyncService');

  static const _playerBoxName = 'dogquest_player';
  static const _notificationsBoxName = 'dogquest_notifications';
  static const _syncMetaBoxName = 'dogquest_sync_meta';

  SupabaseClient get _client => Supabase.instance.client;

  /// Returns the timestamp of the last successful full pull, or null if never synced.
  DateTime? get lastPullTimestamp {
    final box = Hive.box(_syncMetaBoxName);
    final millis = box.get('last_pull_at') as int?;
    return millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }

  /// Runs all pull operations. Each is independently error-guarded.
  ///
  /// Returns early without error if the user is not authenticated.
  Future<void> syncAll() async {
    if (_client.auth.currentSession == null) {
      _log.fine('No active session, skipping pull sync');
      return;
    }

    _log.info('Starting pull sync...');

    await Future.wait([
      pullUserProfile(),
      pullSightingCount(),
      pullNotifications(),
      pullKennelCount(),
    ]);

    // Record last successful pull timestamp.
    try {
      final box = await Hive.openBox(_syncMetaBoxName);
      await box.put('last_pull_at', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _log.warning('Failed to store last_pull_at: $e');
    }

    _log.info('Pull sync complete');
  }

  /// Pulls the current user's profile from the `users` table and updates
  /// the local Hive `dogquest_player` box.
  ///
  /// Skips the write if the local `updated_at` is already equal to or newer
  /// than the server value.
  Future<void> pullUserProfile() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final row = await _client
          .from('users')
          .select('username, display_name, avatar_url, updated_at')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) {
        _log.warning('No user row found for $userId');
        return;
      }

      final box = await Hive.openBox(_playerBoxName);

      // Skip if local data is already current.
      final serverUpdatedAt = row['updated_at'] as String?;
      final localUpdatedAt = box.get('updated_at') as String?;
      if (serverUpdatedAt != null &&
          localUpdatedAt != null &&
          localUpdatedAt.compareTo(serverUpdatedAt) >= 0) {
        _log.fine('User profile already up to date');
        return;
      }

      await box.put('username', row['username']);
      await box.put('display_name', row['display_name']);
      await box.put('avatar_url', row['avatar_url']);
      await box.put('updated_at', serverUpdatedAt);

      _log.info('User profile updated from server');
    } catch (e, st) {
      _log.warning('pullUserProfile failed: $e', e, st);
    }
  }

  /// Queries the count of sightings for the current user on the server and
  /// compares it with the local count. Logs a warning on mismatch but does
  /// **not** overwrite local sightings.
  Future<void> pullSightingCount() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final result = await _client
          .from('sightings')
          .select()
          .eq('user_id', userId)
          .count(CountOption.exact);

      final serverCount = result.count;

      final box = await Hive.openBox(_playerBoxName);
      final localCount = box.get('sighting_count', defaultValue: 0) as int;

      if (serverCount != localCount) {
        _log.warning(
          'Sighting count mismatch: local=$localCount, server=$serverCount',
        );
      } else {
        _log.fine('Sighting counts match: $localCount');
      }
    } catch (e, st) {
      _log.warning('pullSightingCount failed: $e', e, st);
    }
  }

  /// Pulls social notification counts (pending friend requests and unread
  /// comments) and stores them in the `dogquest_notifications` Hive box
  /// for badge display.
  Future<void> pullNotifications() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final box = await Hive.openBox(_notificationsBoxName);

      // Pending friend requests directed at the current user.
      final friendResult = await _client
          .from('friendships')
          .select()
          .eq('to_user_id', userId)
          .eq('status', 'pending')
          .count(CountOption.exact);

      await box.put('pending_friend_requests', friendResult.count);

      // Unread comments (comments on current user's posts, not yet read).
      final commentResult = await _client
          .from('comments')
          .select()
          .eq('target_user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);

      await box.put('unread_comments', commentResult.count);

      _log.info(
        'Notifications updated: ${friendResult.count} friend requests, '
        '${commentResult.count} unread comments',
      );
    } catch (e, st) {
      _log.warning('pullNotifications failed: $e', e, st);
    }
  }

  /// Pulls `kennel_count` from the `users` table and takes the maximum of
  /// local and server values (kennel count is monotonically increasing).
  Future<void> pullKennelCount() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final row = await _client
          .from('users')
          .select('kennel_count')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) return;

      final serverCount = (row['kennel_count'] as num?)?.toInt() ?? 0;

      final box = await Hive.openBox(_playerBoxName);
      final localCount = box.get('kennel_count', defaultValue: 0) as int;

      final resolved = serverCount > localCount ? serverCount : localCount;
      await box.put('kennel_count', resolved);

      if (serverCount != localCount) {
        _log.info(
          'Kennel count reconciled: local=$localCount, server=$serverCount, resolved=$resolved',
        );
      }
    } catch (e, st) {
      _log.warning('pullKennelCount failed: $e', e, st);
    }
  }
}
