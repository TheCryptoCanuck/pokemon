import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:dogquest/services/supabase_social_service.dart';

final _log = Logger('SocialPostGenerator');

/// Milestones that trigger streak posts.
const _streakMilestones = {7, 30, 100};

/// Auto-generates social posts for in-game events.
///
/// Each method is fire-and-forget: errors are caught and logged as warnings.
/// If [_social] is null (offline / not authenticated), all methods silently no-op.
class SocialPostGenerator {
  SocialPostGenerator(this._social);

  final SupabaseSocialService? _social;

  // ---------------------------------------------------------------------------
  // Breed discovery
  // ---------------------------------------------------------------------------

  /// Creates a 'breed_discovered' post.
  /// If rarity is 'rare' or 'legendary', also creates a 'rare_find' post.
  void onBreedDiscovered(
    String breedName, {
    String? rarity,
    int? xpEarned,
  }) {
    _fire(() async {
      await _social!.createPost(
        postType: 'breed_discovered',
        content: 'Discovered a $breedName!',
        breedName: breedName,
        metadata: {
          if (rarity != null) 'rarity': rarity,
          if (xpEarned != null) 'xp_earned': xpEarned,
        },
      );

      if (rarity == 'rare' || rarity == 'legendary') {
        await _social!.createPost(
          postType: 'rare_find',
          content: 'Found a $rarity breed: $breedName!',
          breedName: breedName,
          metadata: {
            'rarity': rarity,
            if (xpEarned != null) 'xp_earned': xpEarned,
          },
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Achievements
  // ---------------------------------------------------------------------------

  void onAchievementUnlocked(
    String achievementName, {
    String? description,
  }) {
    _fire(() async {
      await _social!.createPost(
        postType: 'achievement_unlocked',
        content: 'Unlocked achievement: $achievementName!',
        metadata: {
          'achievement_name': achievementName,
          if (description != null) 'description': description,
        },
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Streaks
  // ---------------------------------------------------------------------------

  /// Creates a 'streak_milestone' post only at 7, 30, or 100 day milestones.
  void onStreakMilestone(int streakDays) {
    if (!_streakMilestones.contains(streakDays)) return;

    _fire(() async {
      await _social!.createPost(
        postType: 'streak_milestone',
        content: 'Reached a $streakDays-day streak!',
        metadata: {
          'streak_days': streakDays,
        },
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Level up
  // ---------------------------------------------------------------------------

  void onLevelUp(int newLevel, String? title) {
    _fire(() async {
      await _social!.createPost(
        postType: 'level_up',
        content: 'Reached level $newLevel!',
        metadata: {
          'level': newLevel,
          if (title != null) 'title': title,
        },
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Set completion
  // ---------------------------------------------------------------------------

  void onSetCompleted(String setName, int breedCount) {
    _fire(() async {
      await _social!.createPost(
        postType: 'set_completed',
        content: 'Completed the $setName collection ($breedCount breeds)!',
        metadata: {
          'set_name': setName,
          'breed_count': breedCount,
        },
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Lost dog alerts
  // ---------------------------------------------------------------------------

  void onLostDogAlert(String dogName, String breed) {
    _fire(() async {
      await _social!.createPost(
        postType: 'lost_dog_alert',
        content: '$dogName ($breed) is missing! Please help find them.',
        metadata: {
          'dog_name': dogName,
          'breed': breed,
        },
      );
    });
  }

  void onLostDogFound(String dogName, String breed) {
    _fire(() async {
      await _social!.createPost(
        postType: 'lost_dog_found',
        content: '$dogName ($breed) has been found! 🎉',
        metadata: {
          'dog_name': dogName,
          'breed': breed,
        },
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Friendships
  // ---------------------------------------------------------------------------

  void onFriendshipFormed(String dogName, String friendDogName) {
    _fire(() async {
      await _social!.createPost(
        postType: 'friendship_formed',
        content: '$dogName and $friendDogName are now friends!',
        metadata: {
          'dog_name': dogName,
          'friend_dog_name': friendDogName,
        },
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Internal helper
  // ---------------------------------------------------------------------------

  /// Wraps an async post call in fire-and-forget semantics.
  /// Silently returns if [_social] is null. Catches and logs all errors.
  void _fire(Future<void> Function() action) {
    if (_social == null) return;

    action().catchError((Object error, StackTrace stack) {
      _log.warning('Failed to create social post', error, stack);
    });
  }
}

// -----------------------------------------------------------------------------
// Riverpod provider
// -----------------------------------------------------------------------------

final socialPostGeneratorProvider = Provider<SocialPostGenerator>((ref) {
  final social = ref.watch(supabaseSocialServiceProvider);
  return SocialPostGenerator(social);
});
