import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('FlashChallengeService');

// ─── Challenge Types ─────────────────────────────────────────────────────────

enum FlashChallengeType {
  speedRound,
  rarityHunt,
  familyFocus,
  doubleDown,
}

// ─── FlashChallenge Model ────────────────────────────────────────────────────

class FlashChallenge {
  final String id;
  final FlashChallengeType type;
  final String title;
  final String description;
  final int target;
  final int xpReward;
  final int progress;
  final bool completed;
  final bool claimed;
  final DateTime createdAt;
  final DateTime expiresAt;

  const FlashChallenge({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.target,
    required this.xpReward,
    this.progress = 0,
    this.completed = false,
    this.claimed = false,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => !isExpired && !claimed;

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  double get progressFraction => (progress / target).clamp(0.0, 1.0);

  FlashChallenge copyWith({
    int? progress,
    bool? completed,
    bool? claimed,
  }) =>
      FlashChallenge(
        id: id,
        type: type,
        title: title,
        description: description,
        target: target,
        xpReward: xpReward,
        progress: progress ?? this.progress,
        completed: completed ?? this.completed,
        claimed: claimed ?? this.claimed,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'title': title,
        'description': description,
        'target': target,
        'xpReward': xpReward,
        'progress': progress,
        'completed': completed,
        'claimed': claimed,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      };

  factory FlashChallenge.fromMap(Map<dynamic, dynamic> map) => FlashChallenge(
        id: map['id'] as String? ?? '',
        type: FlashChallengeType.values[(map['type'] as int?) ?? 0],
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        target: (map['target'] as num?)?.toInt() ?? 1,
        xpReward: (map['xpReward'] as num?)?.toInt() ?? 0,
        progress: (map['progress'] as num?)?.toInt() ?? 0,
        completed: map['completed'] as bool? ?? false,
        claimed: map['claimed'] as bool? ?? false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (map['createdAt'] as num?)?.toInt() ?? 0),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
            (map['expiresAt'] as num?)?.toInt() ?? 0),
      );
}

// ─── State ───────────────────────────────────────────────────────────────────

class FlashChallengeState {
  final FlashChallenge? activeChallenge;
  final DateTime? lastOfferedAt;

  const FlashChallengeState({
    this.activeChallenge,
    this.lastOfferedAt,
  });

  bool get hasActiveChallenge =>
      activeChallenge != null && activeChallenge!.isActive;

  Duration get timeRemaining => activeChallenge?.timeRemaining ?? Duration.zero;

  FlashChallengeState copyWith({
    FlashChallenge? activeChallenge,
    DateTime? lastOfferedAt,
    bool clearChallenge = false,
  }) =>
      FlashChallengeState(
        activeChallenge:
            clearChallenge ? null : (activeChallenge ?? this.activeChallenge),
        lastOfferedAt: lastOfferedAt ?? this.lastOfferedAt,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class FlashChallengeNotifier extends StateNotifier<FlashChallengeState> {
  final Box _box;
  final Random _rng;

  FlashChallengeNotifier(this._box)
      : _rng = Random(),
        super(const FlashChallengeState()) {
    _loadFromStorage();
  }

  // ---- Persistence ----

  void _loadFromStorage() {
    try {
      final challengeMap = _box.get('active_challenge') as Map?;
      final lastOfferedMs = _box.get('last_offered_at') as int?;

      FlashChallenge? challenge;
      if (challengeMap != null) {
        challenge = FlashChallenge.fromMap(challengeMap);
        // Clear expired + claimed challenges
        if (challenge.isExpired && challenge.claimed) {
          challenge = null;
          _box.delete('active_challenge');
        }
      }

      state = FlashChallengeState(
        activeChallenge: challenge,
        lastOfferedAt: lastOfferedMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastOfferedMs)
            : null,
      );
    } catch (e, st) {
      _log.warning('Failed to load flash challenge state', e, st);
    }
  }

  void _save() {
    final challenge = state.activeChallenge;
    if (challenge != null) {
      _box.put('active_challenge', challenge.toMap());
    } else {
      _box.delete('active_challenge');
    }
    if (state.lastOfferedAt != null) {
      _box.put('last_offered_at', state.lastOfferedAt!.millisecondsSinceEpoch);
    }
  }

  // ---- Public API ----

  /// Called on app open. May generate a flash challenge with 25% probability.
  /// Respects cooldowns: at least 4 hours between offers.
  void checkAndOffer() {
    final now = DateTime.now();

    // Don't offer if there's already an active (non-expired) challenge
    if (state.hasActiveChallenge) return;

    // Clean up expired challenges
    final current = state.activeChallenge;
    if (current != null && current.isExpired && !current.claimed) {
      state = state.copyWith(clearChallenge: true);
      _save();
    }

    // Cooldown: 4 hours between offers
    if (state.lastOfferedAt != null) {
      final elapsed = now.difference(state.lastOfferedAt!);
      if (elapsed.inHours < 4) return;
    }

    // 25% chance
    if (_rng.nextDouble() > 0.25) return;

    // Generate a new challenge
    final challenge = _generateChallenge(now);
    state = FlashChallengeState(
      activeChallenge: challenge,
      lastOfferedAt: now,
    );
    _save();
    _log.info('Flash challenge offered: ${challenge.title}');
  }

  /// Record progress toward the active challenge.
  /// Call this when the player identifies a dog or completes a relevant action.
  void recordProgress({int increment = 1}) {
    final challenge = state.activeChallenge;
    if (challenge == null || !challenge.isActive || challenge.completed) return;

    final newProgress =
        (challenge.progress + increment).clamp(0, challenge.target);
    final completed = newProgress >= challenge.target;

    state = state.copyWith(
      activeChallenge: challenge.copyWith(
        progress: newProgress,
        completed: completed,
      ),
    );
    _save();

    if (completed) {
      _log.info('Flash challenge completed: ${challenge.title}');
    }
  }

  /// Claim the reward for a completed challenge.
  /// Returns the XP reward, or 0 if nothing to claim.
  int claimReward() {
    final challenge = state.activeChallenge;
    if (challenge == null || !challenge.completed || challenge.claimed)
      return 0;

    final xp = challenge.xpReward;
    state = state.copyWith(
      activeChallenge: challenge.copyWith(claimed: true),
    );
    _save();
    _log.info('Flash challenge claimed: +$xp XP');
    return xp;
  }

  /// Dismiss an expired challenge without claiming.
  void dismiss() {
    state = state.copyWith(clearChallenge: true);
    _save();
  }

  // ---- Generation ----

  FlashChallenge _generateChallenge(DateTime now) {
    final type = FlashChallengeType
        .values[_rng.nextInt(FlashChallengeType.values.length)];

    switch (type) {
      case FlashChallengeType.speedRound:
        return FlashChallenge(
          id: 'flash_${now.millisecondsSinceEpoch}',
          type: type,
          title: 'Speed Round',
          description: 'Identify 3 dogs in 30 minutes',
          target: 3,
          xpReward: 500,
          createdAt: now,
          expiresAt: now.add(const Duration(minutes: 30)),
        );
      case FlashChallengeType.rarityHunt:
        return FlashChallenge(
          id: 'flash_${now.millisecondsSinceEpoch}',
          type: type,
          title: 'Rarity Hunt',
          description: 'Find a rare or legendary dog in 1 hour',
          target: 1,
          xpReward: 750,
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
        );
      case FlashChallengeType.familyFocus:
        return FlashChallenge(
          id: 'flash_${now.millisecondsSinceEpoch}',
          type: type,
          title: 'Group Focus',
          description: 'Identify 2 dogs from the same group in 1 hour',
          target: 2,
          xpReward: 400,
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
        );
      case FlashChallengeType.doubleDown:
        return FlashChallenge(
          id: 'flash_${now.millisecondsSinceEpoch}',
          type: type,
          title: 'Double Down',
          description: 'Your next 5 identifications give double XP',
          target: 5,
          xpReward: 0, // reward is inline double XP, not a lump sum
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 2)),
        );
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final flashChallengeProvider =
    StateNotifierProvider<FlashChallengeNotifier, FlashChallengeState>((ref) {
  throw UnimplementedError(
    'flashChallengeProvider must be overridden after Hive init',
  );
});
