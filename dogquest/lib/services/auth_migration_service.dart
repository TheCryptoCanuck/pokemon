import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import 'package:dogquest/services/supabase_auth_service.dart';
import 'package:dogquest/services/supabase_user_service.dart';

final _log = Logger('AuthMigrationService');

/// Handles migration from legacy Hive-based auth to Supabase Auth.
/// Checks for existing local credentials and prompts the user to upgrade.
class AuthMigrationService {
  final SupabaseAuthService _authService;
  final SupabaseUserService _userService;

  static const _playerStatsBox = 'dogquest_player_stats';
  static const _migrationKey = 'migration_prompted';

  AuthMigrationService(this._authService, this._userService);

  /// Check if legacy Hive auth data exists (email stored in player_stats box).
  Future<bool> hasLegacyAuth() async {
    try {
      final box = Hive.box(_playerStatsBox);
      final email = box.get('email') as String?;
      final hasToken = box.get('has_auth_token', defaultValue: false) as bool;
      return email != null && hasToken;
    } catch (e) {
      _log.warning('Failed to check legacy auth: $e');
      return false;
    }
  }

  /// Whether the migration prompt has already been shown.
  bool get wasPrompted {
    try {
      final box = Hive.box(_playerStatsBox);
      return box.get(_migrationKey, defaultValue: false) as bool;
    } catch (e) {
      return false;
    }
  }

  /// Mark that the migration prompt has been shown (don't show again).
  Future<void> markPrompted() async {
    try {
      final box = Hive.box(_playerStatsBox);
      await box.put(_migrationKey, true);
    } catch (e) {
      _log.warning('Failed to mark migration prompted: $e');
    }
  }

  /// Whether migration is needed: has legacy auth, no Supabase session, not yet prompted.
  bool get shouldPromptMigration {
    // Synchronous check — hasLegacyAuth needs async, so we check what we can
    if (_authService.isAuthenticated) return false;
    if (wasPrompted) return false;
    return true; // Caller should also await hasLegacyAuth() for full check
  }

  /// Get the legacy email for pre-filling the upgrade form.
  String? get legacyEmail {
    try {
      final box = Hive.box(_playerStatsBox);
      return box.get('email') as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get the legacy username for pre-filling the upgrade form.
  String? get legacyUsername {
    try {
      final box = Hive.box(_playerStatsBox);
      return box.get('username') as String?;
    } catch (e) {
      return null;
    }
  }

  /// Migrate legacy auth to Supabase. Creates a new Supabase account
  /// with the same email, then creates the user profile row.
  /// Returns true on success, false on failure.
  Future<bool> migrateToSupabase({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // 1. Create Supabase account
      final response = await _authService.signUp(
        email: email,
        password: password,
        username: username,
      );

      final user = response.user;
      if (user == null) {
        _log.warning('Migration signup returned no user');
        return false;
      }

      // 2. Create user profile in the users table
      await _userService.createProfile(user);

      // 3. Sync existing local stats to the new profile
      await _syncLocalStats(user.id);

      // 4. Clear legacy auth data (but keep game data!)
      await _clearLegacyAuth();

      _log.info('Migration complete for $email');
      return true;
    } on SupabaseAuthException catch (e) {
      _log.warning('Migration failed: $e');
      rethrow;
    } catch (e) {
      _log.warning('Migration failed unexpectedly: $e');
      return false;
    }
  }

  /// Sync local player stats to the new Supabase profile.
  Future<void> _syncLocalStats(String userId) async {
    try {
      final box = Hive.box(_playerStatsBox);
      final playerData = box.get('player');
      if (playerData == null) return;

      final player =
          playerData is Map ? Map<String, dynamic>.from(playerData) : {};

      await _userService.syncStats(
        userId,
        totalXp: player['totalXp'] as int? ?? 0,
        level: player['level'] as int? ?? 1,
        totalSightings: player['totalSightings'] as int? ?? 0,
        kennelCount: player['kennelCount'] as int? ?? 0,
        currentStreak: player['currentStreak'] as int? ?? 0,
        longestStreak: player['longestStreak'] as int? ?? 0,
      );
      _log.info('Local stats synced to Supabase');
    } catch (e) {
      _log.warning('Failed to sync local stats (non-critical): $e');
      // Non-critical — stats can sync later
    }
  }

  /// Clear legacy Hive auth data but preserve game data.
  Future<void> _clearLegacyAuth() async {
    try {
      final box = Hive.box(_playerStatsBox);
      // Only clear auth-specific keys, keep game data intact
      await box.delete('has_auth_token');
      // Keep email/username — they're now in Supabase too
      _log.info('Legacy auth data cleared');
    } catch (e) {
      _log.warning('Failed to clear legacy auth: $e');
    }
  }
}

/// Riverpod provider for AuthMigrationService.
final authMigrationServiceProvider = Provider<AuthMigrationService>((ref) {
  return AuthMigrationService(
    ref.read(supabaseAuthServiceProvider),
    ref.read(supabaseUserServiceProvider),
  );
});
