import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../helpers/game_helpers.dart';
import '../models/dog.dart';
import 'analytics_service.dart';
import 'activity_tracker_service.dart';
import 'backend_sync_service.dart';
import 'combo_service.dart';
import 'daily_challenge_service.dart';
import 'daily_dog_service.dart';
import 'dog_group_service.dart';
import 'dog_mastery_service.dart';
import 'dog_service.dart';
import 'flash_challenge_service.dart';
import 'haptic_service.dart';
import 'kennel_service.dart';
import 'location_service.dart';
import 'mystery_reward_service.dart';
import 'player_service.dart';
import 'seasonal_event_service.dart';
import 'sighting_service.dart';
import 'dog_social_service.dart';

final _log = Logger('IdentificationOrchestrator');

/// Result object returned by [IdentificationOrchestrator.processIdentification].
///
/// Contains all information the UI needs to show animations, dialogs,
/// snackbars, and overlays after a dog is added to the kennel.
class IdentificationOutcome {
  /// Whether this dog was already in the kennel before this identification.
  final bool alreadyOwned;

  /// Whether the dog was successfully added to the kennel (false if duplicate).
  final bool isNewDog;

  /// Total effective XP earned (after all multipliers). Zero if already owned.
  final int xpEarned;

  /// The combined XP multiplier applied (streak * seasonal * family * combo * mystery).
  final double totalMultiplier;

  /// Whether the player leveled up from this identification.
  final bool leveledUp;

  /// The player's new level (only meaningful if [leveledUp] is true).
  final int newLevel;

  /// List of achievement keys that were newly unlocked.
  final List<String> achievementsUnlocked;

  /// Mystery reward rolled, or null if none was triggered.
  final MysteryReward? mysteryReward;

  /// Current combo count after this identification.
  final int comboCount;

  /// Whether the identified dog was the daily dog and bonus was claimed.
  final bool isDailyDogBonus;

  /// The daily dog bonus XP amount (0 if not the daily dog or already claimed).
  final int dailyDogBonusXp;

  /// Encounter milestone text (e.g. "5th sighting!"), or null if no milestone.
  final String? milestoneText;

  /// Whether the dog has an audio URL for playback.
  final bool hasAudio;

  /// The dog's audio URL (empty string if none).
  final String audioUrl;

  /// Whether the location service has GPS coordinates (for data consent prompt).
  final bool hasLocation;

  const IdentificationOutcome({
    required this.alreadyOwned,
    required this.isNewDog,
    required this.xpEarned,
    required this.totalMultiplier,
    required this.leveledUp,
    required this.newLevel,
    required this.achievementsUnlocked,
    required this.mysteryReward,
    required this.comboCount,
    required this.isDailyDogBonus,
    required this.dailyDogBonusXp,
    required this.milestoneText,
    required this.hasAudio,
    required this.audioUrl,
    required this.hasLocation,
  });
}

/// Orchestrates the full identification flow: logging, gamification,
/// XP calculation, achievements, and backend sync.
///
/// Extracted from the former `_addDog()` god method in IdentifyScreen.
/// The UI layer calls [processIdentification] and uses the returned
/// [IdentificationOutcome] to decide which animations/dialogs to show.
class IdentificationOrchestrator {
  final Ref _ref;

  IdentificationOrchestrator(this._ref);

  /// Process a dog identification end-to-end.
  ///
  /// This method handles: sighting logging, GPS, activity tracking, dog mastery,
  /// daily challenges, combos, flash challenges, mystery rewards, kennel insertion,
  /// analytics, seasonal XP, family mastery bonus, combo multiplier, XP award,
  /// level-up detection, achievement unlock, encounter milestones, and backend sync.
  ///
  /// Returns an [IdentificationOutcome] that the UI uses to show animations,
  /// dialogs, and overlays. The UI should NOT perform any business logic — only
  /// react to the outcome.
  Future<IdentificationOutcome> processIdentification(
    Dog dog,
    double confidence,
    String source, {
    double? lat,
    double? lon,
    double? accuracy,
  }) async {
    final kennelSvc = _ref.read(kennelServiceProvider);
    final alreadyOwned = kennelSvc.contains(dog.name);

    // ── Log sighting (regardless of already owned) ──────────────────────
    final locationSvc = _ref.read(locationServiceProvider);
    _ref.read(sightingServiceProvider).log(Sighting(
      dogName: dog.name,
      timestamp: DateTime.now(),
      confidence: confidence,
      source: source,
      latitude: lat ?? locationSvc.latitude,
      longitude: lon ?? locationSvc.longitude,
      accuracy: accuracy ?? locationSvc.accuracy,
    ));
    _ref.read(playerProvider.notifier).recordSighting();

    // ── Post to social feed ──────────────────────────────────────────────
    try {
      final socialSvc = _ref.read(dogSocialServiceProvider);
      final isNew = !alreadyOwned;
      socialSvc.addFeedItem(FeedItem(
        id: '${dog.name}-${DateTime.now().millisecondsSinceEpoch}',
        dogName: dog.name,
        breed: dog.name,
        type: isNew ? 'sighting' : 'photo',
        text: isNew
            ? 'Discovered a ${dog.name}! ${(confidence * 100).toStringAsFixed(0)}% confidence'
            : 'Spotted a ${dog.name} again',
        timestamp: DateTime.now(),
        latitude: lat ?? locationSvc.latitude,
        longitude: lon ?? locationSvc.longitude,
      ));
    } catch (_) {} // social service may not be initialized in tests

    // ── Record activity for heatmap ─────────────────────────────────────
    _ref.read(activityTrackerProvider).recordIdentification();

    // ── Record dog mastery ──────────────────────────────────────────────
    _ref.read(dogMasteryProvider.notifier).recordSighting(dog.name);

    // ── Record daily challenge progress ─────────────────────────────────
    final familySvc = _ref.read(dogGroupServiceProvider);
    final dogGroupForChallenge = familySvc.familyOf(dog);
    _ref.read(dailyChallengeProvider.notifier).recordIdentification(
      dogRarity: dog.rarity,
      familyId: dogGroupForChallenge?.id,
      source: source,
    );

    // ── Record combo ────────────────────────────────────────────────────
    _ref.read(comboProvider.notifier).recordIdentification();
    final comboCount = _ref.read(comboProvider).count;
    if (comboCount >= 2) {
      HapticService.combo(comboCount);
    } else {
      HapticService.light();
    }

    // ── Record flash challenge progress ─────────────────────────────────
    _ref.read(flashChallengeProvider.notifier).recordProgress();

    // ── Roll for mystery reward ─────────────────────────────────────────
    final mysteryReward = _ref.read(mysteryRewardProvider.notifier).rollForReward();

    // ── Check location for data consent prompt ──────────────────────────
    final hasLocation = locationSvc.hasLocation;

    // ── Try adding to kennel ────────────────────────────────────────────
    if (!kennelSvc.add(dog.name)) {
      _ref.read(analyticsProvider).track('dog_skipped', {
        'dog_name': dog.name,
        'rarity': dog.rarity.name,
        'already_owned': true,
      });

      return IdentificationOutcome(
        alreadyOwned: alreadyOwned,
        isNewDog: false,
        xpEarned: 0,
        totalMultiplier: 1.0,
        leveledUp: false,
        newLevel: _ref.read(playerProvider).level,
        achievementsUnlocked: const [],
        mysteryReward: mysteryReward,
        comboCount: comboCount,
        isDailyDogBonus: false,
        dailyDogBonusXp: 0,
        milestoneText: null,
        hasAudio: false,
        audioUrl: '',
        hasLocation: hasLocation,
      );
    }

    // ── New dog added to kennel ─────────────────────────────────────────
    _ref.read(analyticsProvider).track('dog_added_to_kennel', {
      'dog_name': dog.name,
      'rarity': dog.rarity.name,
      'xp_earned': dog.xp,
      'kennel_count': kennelSvc.count,
    });

    // ── Check daily dog bonus ───────────────────────────────────────────
    int dailyDogBonusXp = 0;
    bool isDailyDogBonus = false;
    final dailySvc = _ref.read(dailyDogServiceProvider);
    if (dog.name == dailySvc.todaysDog.name) {
      final bonus = dailySvc.claimDailyBonus();
      if (bonus > 0) {
        dailyDogBonusXp = bonus;
        isDailyDogBonus = true;
      }
    }

    // ── Compute XP multipliers ──────────────────────────────────────────
    final playerNotifier = _ref.read(playerProvider.notifier);
    final dogSvc = _ref.read(dogServiceProvider);
    final seasonalSvc = _ref.read(seasonalEventServiceProvider);
    final collectedDogs = kennelSvc.collectedDogs;

    final seasonalMultiplier = seasonalSvc.currentXpMultiplier;
    final dogGroup = familySvc.familyOf(dog);
    final familyBonus = dogGroup != null
        ? (familySvc.progressFor(dogGroup.id)?.xpBonus ?? 1.0)
        : 1.0;

    final streakMultiplier = _ref.read(playerProvider).streakXpMultiplier;
    final comboMultiplier = _ref.read(comboProvider).multiplier;
    final mysteryMultiplier = _ref.read(mysteryRewardProvider.notifier).consumeMultiplier();
    const discoveryBonus = 1.5;
    final totalMultiplier =
        streakMultiplier * seasonalMultiplier * familyBonus * comboMultiplier * mysteryMultiplier * discoveryBonus;
    final effectiveXp = (dog.xp * totalMultiplier).round();
    _log.info('Discovery bonus: 1.5x XP for new breed!');

    // ── Award XP and check achievements ─────────────────────────────────
    final oldLevel = _ref.read(playerProvider).level;
    final newAchievements = playerNotifier.addXpForDog(
      dog,
      kennelSvc.count,
      collectedDogs: collectedDogs,
      allDogs: dogSvc.all,
      seasonalMultiplier: seasonalMultiplier,
      familyBonus: familyBonus,
      comboMultiplier: comboMultiplier,
      mysteryMultiplier: mysteryMultiplier * discoveryBonus,
    );

    final newLevel = _ref.read(playerProvider).level;
    final didLevelUp = newLevel > oldLevel;
    if (didLevelUp) {
      HapticService.celebration();
    }

    // ── Track achievement analytics ─────────────────────────────────────
    for (final key in newAchievements) {
      final a = achievements[key];
      if (a == null) continue;
      _ref.read(analyticsProvider).track('achievement_unlocked', {
        'achievement_key': key,
        'achievement_name': a.$2,
      });
    }

    // ── Encounter milestone ─────────────────────────────────────────────
    final sightingSvc = _ref.read(sightingServiceProvider);
    final milestoneText = sightingSvc.encounterMilestoneText(dog.name);

    // ── Backend sync (fire-and-forget) ──────────────────────────────────
    _ref.read(backendSyncProvider)
        .syncDogToCollection(dog.name, confidence: confidence, source: source)
        .then((resp) {
      if (resp != null) {
        _log.info('Backend sync complete for ${dog.name}');
      }
    }).catchError((e) {
      _log.warning('Backend sync error: $e');
    });

    return IdentificationOutcome(
      alreadyOwned: alreadyOwned,
      isNewDog: true,
      xpEarned: effectiveXp,
      totalMultiplier: totalMultiplier,
      leveledUp: didLevelUp,
      newLevel: newLevel,
      achievementsUnlocked: newAchievements,
      mysteryReward: mysteryReward,
      comboCount: comboCount,
      isDailyDogBonus: isDailyDogBonus,
      dailyDogBonusXp: dailyDogBonusXp,
      milestoneText: milestoneText,
      hasAudio: dog.audioUrl.isNotEmpty,
      audioUrl: dog.audioUrl,
      hasLocation: hasLocation,
    );
  }
}

/// Riverpod provider for [IdentificationOrchestrator].
///
/// Reads all required service providers via [Ref], so it does not need
/// to be manually overridden in main.dart — it works as long as the
/// underlying service providers are overridden.
final identificationOrchestratorProvider =
    Provider<IdentificationOrchestrator>((ref) {
  return IdentificationOrchestrator(ref);
});
