import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger('SupabaseUserService');

class SupabaseUserService {
  final SupabaseClient _client;
  static const _hiveBoxName = 'dogquest_user_profile';

  SupabaseUserService(this._client);

  /// Create a user profile row in the `users` table after signup.
  /// Reads username/display_name from auth user metadata.
  Future<Map<String, dynamic>> createProfile(User user) async {
    final metadata = user.userMetadata ?? {};
    final username = metadata['username'] as String? ??
        user.email?.split('@').first ??
        'user';
    final displayName = metadata['display_name'] as String? ?? username;

    final profile = {
      'id': user.id,
      'email': user.email!,
      'username': username,
      'display_name': displayName,
    };

    try {
      final response = await _client
          .from('users')
          .upsert(profile, onConflict: 'id')
          .select()
          .single();

      await _cacheProfile(response);
      _log.info('Profile created for ${user.email}');
      return response;
    } catch (e) {
      _log.warning('Failed to create profile: $e');
      // Cache what we have locally even if remote fails
      await _cacheProfile(profile);
      rethrow;
    }
  }

  /// Fetch the user profile from Supabase by auth uid.
  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    try {
      final response =
          await _client.from('users').select().eq('id', userId).single();

      await _cacheProfile(response);
      _log.info('Profile fetched for $userId');
      return response;
    } catch (e) {
      _log.warning('Failed to fetch profile, trying cache: $e');
      final cached = getCachedProfile();
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Update fields on the user profile.
  Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _client
          .from('users')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      await _cacheProfile(response);
      _log.info('Profile updated for $userId');
      return response;
    } catch (e) {
      _log.warning('Failed to update profile: $e');
      rethrow;
    }
  }

  /// Sync local gamification stats (XP, level, streak, kennel count) to Supabase.
  Future<void> syncStats(
    String userId, {
    required int totalXp,
    required int level,
    required int totalSightings,
    required int kennelCount,
    required int currentStreak,
    required int longestStreak,
  }) async {
    try {
      await _client.from('users').update({
        'total_xp': totalXp,
        'level': level,
        'total_sightings': totalSightings,
        'kennel_count': kennelCount,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_active_date': DateTime.now().toIso8601String().substring(0, 10),
      }).eq('id', userId);
      _log.info('Stats synced for $userId');
    } catch (e) {
      _log.warning('Failed to sync stats: $e');
      // Non-critical — stats will sync next time
    }
  }

  /// Check if a username is available.
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      return response == null;
    } catch (e) {
      _log.warning('Username check failed: $e');
      return true; // Assume available if check fails; server will enforce uniqueness
    }
  }

  /// Get the locally cached profile (for offline access).
  Map<String, dynamic>? getCachedProfile() {
    try {
      final box = Hive.box(_hiveBoxName);
      final data = box.get('profile');
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      _log.warning('Failed to read cached profile: $e');
      return null;
    }
  }

  /// Cache profile data to Hive for offline access.
  Future<void> _cacheProfile(Map<String, dynamic> profile) async {
    try {
      final box = await Hive.openBox(_hiveBoxName);
      await box.put('profile', profile);
    } catch (e) {
      _log.warning('Failed to cache profile: $e');
    }
  }
}

/// Riverpod provider for SupabaseUserService.
final supabaseUserServiceProvider = Provider<SupabaseUserService>((ref) {
  return SupabaseUserService(Supabase.instance.client);
});
