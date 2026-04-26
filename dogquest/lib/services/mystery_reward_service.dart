import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('MysteryRewardService');

// ─── Reward Types ────────────────────────────────────────────────────────────

enum MysteryRewardType {
  bonusXp,
  streakSaver,
  xpMultiplier,
  rarityBoost,
  titleUnlock,
}

/// Cosmetic titles that can be unlocked via mystery rewards.
const _availableTitles = <String>[
  'Lucky Doger',
  "Fortune's Paw",
  'Golden Eye',
  'Breed Whisperer',
  'Pack Leader',
  'Canine Fortune',
  'Twilight Watcher',
  'Storm Chaser',
];

/// A single mystery reward result.
class MysteryReward {
  final MysteryRewardType type;

  /// For [bonusXp]: the XP amount. For [xpMultiplier]: 2 or 3.
  /// For [rarityBoost]: number of boosted IDs remaining (always 3).
  /// For others: unused (0).
  final int value;

  /// For [titleUnlock]: the title string. Null otherwise.
  final String? title;

  const MysteryReward({
    required this.type,
    this.value = 0,
    this.title,
  });

  String get displayText {
    switch (type) {
      case MysteryRewardType.bonusXp:
        return '+$value XP';
      case MysteryRewardType.streakSaver:
        return 'Streak Saver Earned!';
      case MysteryRewardType.xpMultiplier:
        return 'Next ID: ${value}x XP!';
      case MysteryRewardType.rarityBoost:
        return 'Rare Boost Active!';
      case MysteryRewardType.titleUnlock:
        return 'New Title: $title';
    }
  }

  Map<String, dynamic> toMap() => {
        'type': type.index,
        'value': value,
        'title': title,
      };

  factory MysteryReward.fromMap(Map<dynamic, dynamic> map) => MysteryReward(
        type: MysteryRewardType.values[(map['type'] as int?) ?? 0],
        value: (map['value'] as num?)?.toInt() ?? 0,
        title: map['title'] as String?,
      );
}

// ─── State ───────────────────────────────────────────────────────────────────

class MysteryRewardState {
  final double pendingMultiplier;
  final int rarityBoostRemaining;
  final Set<String> unlockedTitles;
  final int pityCounter;
  final int streakSaverTokens;

  const MysteryRewardState({
    this.pendingMultiplier = 1.0,
    this.rarityBoostRemaining = 0,
    this.unlockedTitles = const {},
    this.pityCounter = 0,
    this.streakSaverTokens = 0,
  });

  MysteryRewardState copyWith({
    double? pendingMultiplier,
    int? rarityBoostRemaining,
    Set<String>? unlockedTitles,
    int? pityCounter,
    int? streakSaverTokens,
  }) =>
      MysteryRewardState(
        pendingMultiplier: pendingMultiplier ?? this.pendingMultiplier,
        rarityBoostRemaining: rarityBoostRemaining ?? this.rarityBoostRemaining,
        unlockedTitles: unlockedTitles ?? this.unlockedTitles,
        pityCounter: pityCounter ?? this.pityCounter,
        streakSaverTokens: streakSaverTokens ?? this.streakSaverTokens,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class MysteryRewardNotifier extends StateNotifier<MysteryRewardState> {
  static const _boxName = 'dogquest_mystery_rewards';

  /// Reward weight table (must sum to 100).
  static const _weights = <MysteryRewardType, int>{
    MysteryRewardType.bonusXp: 40,
    MysteryRewardType.streakSaver: 15,
    MysteryRewardType.xpMultiplier: 25,
    MysteryRewardType.rarityBoost: 10,
    MysteryRewardType.titleUnlock: 10,
  };

  static const _baseChance = 0.30;
  static const _pityIncrement = 0.05;

  late Box _box;
  bool _initialized = false;
  final Random _rng = Random();

  MysteryRewardNotifier() : super(const MysteryRewardState());

  /// Must call after construction to open the Hive box and load state.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _initialized = true;
    _loadState();
    _log.info('MysteryReward loaded — pity: ${state.pityCounter}, '
        'multiplier: ${state.pendingMultiplier}, '
        'titles: ${state.unlockedTitles.length}');
  }

  void _loadState() {
    state = MysteryRewardState(
      pendingMultiplier:
          (_box.get('pendingMultiplier', defaultValue: 1.0) as num).toDouble(),
      rarityBoostRemaining:
          (_box.get('rarityBoostRemaining', defaultValue: 0) as num).toInt(),
      unlockedTitles: Set<String>.from(
        (_box.get('unlockedTitles', defaultValue: <dynamic>[]) as List)
            .cast<String>(),
      ),
      pityCounter: (_box.get('pityCounter', defaultValue: 0) as num).toInt(),
      streakSaverTokens:
          (_box.get('streakSaverTokens', defaultValue: 0) as num).toInt(),
    );
  }

  void _saveState() {
    if (!_initialized) return;
    _box.put('pendingMultiplier', state.pendingMultiplier);
    _box.put('rarityBoostRemaining', state.rarityBoostRemaining);
    _box.put('unlockedTitles', state.unlockedTitles.toList());
    _box.put('pityCounter', state.pityCounter);
    _box.put('streakSaverTokens', state.streakSaverTokens);
  }

  // ─── Public API ─────────────────────────────────────────────────────

  /// Roll for a mystery reward after an identification.
  /// Returns the reward if one was triggered, or null.
  MysteryReward? rollForReward() {
    final chance = _baseChance + (state.pityCounter * _pityIncrement);
    final roll = _rng.nextDouble();

    if (roll > chance) {
      // No reward — increment pity counter.
      state = state.copyWith(pityCounter: state.pityCounter + 1);
      _saveState();
      _log.fine(
        'No mystery reward (roll=$roll, needed<=$chance, pity=${state.pityCounter})',
      );
      return null;
    }

    // Won a reward — reset pity counter.
    final reward = _pickReward();
    _applyReward(reward);
    state = state.copyWith(pityCounter: 0);
    _saveState();
    _log.info('Mystery reward! ${reward.type.name}: ${reward.displayText}');
    return reward;
  }

  /// Consume and return the pending XP multiplier. Resets to 1.0.
  double consumeMultiplier() {
    final multiplier = state.pendingMultiplier;
    if (multiplier != 1.0) {
      state = state.copyWith(pendingMultiplier: 1.0);
      _saveState();
      _log.info('Consumed XP multiplier: ${multiplier}x');
    }
    return multiplier;
  }

  /// Consume one rarity boost charge. Returns true if a charge was available.
  bool consumeRarityBoost() {
    if (state.rarityBoostRemaining <= 0) return false;
    state =
        state.copyWith(rarityBoostRemaining: state.rarityBoostRemaining - 1);
    _saveState();
    _log.info(
      'Rarity boost consumed (${state.rarityBoostRemaining} remaining)',
    );
    return true;
  }

  /// Consume one streak saver token. Returns true if a token was available.
  bool consumeStreakSaver() {
    if (state.streakSaverTokens <= 0) return false;
    state = state.copyWith(streakSaverTokens: state.streakSaverTokens - 1);
    _saveState();
    _log.info('Streak saver consumed (${state.streakSaverTokens} remaining)');
    return true;
  }

  /// All cosmetic titles the player has unlocked.
  List<String> get unlockedTitles => state.unlockedTitles.toList()..sort();

  // ─── Internal ───────────────────────────────────────────────────────

  MysteryReward _pickReward() {
    // Weighted random selection.
    final totalWeight = _weights.values.fold(0, (a, b) => a + b);
    var pick = _rng.nextInt(totalWeight);
    MysteryRewardType selectedType = MysteryRewardType.bonusXp;

    for (final entry in _weights.entries) {
      pick -= entry.value;
      if (pick < 0) {
        selectedType = entry.key;
        break;
      }
    }

    // If titleUnlock but all titles already unlocked, fall back to bonusXp.
    if (selectedType == MysteryRewardType.titleUnlock &&
        state.unlockedTitles.length >= _availableTitles.length) {
      selectedType = MysteryRewardType.bonusXp;
    }

    switch (selectedType) {
      case MysteryRewardType.bonusXp:
        // Random XP between 50 and 500, in increments of 25.
        final xp = ((_rng.nextInt(19) + 2) * 25); // 50..500
        return MysteryReward(type: selectedType, value: xp);

      case MysteryRewardType.streakSaver:
        return const MysteryReward(
          type: MysteryRewardType.streakSaver,
          value: 1,
        );

      case MysteryRewardType.xpMultiplier:
        final multiplier = _rng.nextBool() ? 2 : 3;
        return MysteryReward(type: selectedType, value: multiplier);

      case MysteryRewardType.rarityBoost:
        return const MysteryReward(
          type: MysteryRewardType.rarityBoost,
          value: 3,
        );

      case MysteryRewardType.titleUnlock:
        final available = _availableTitles
            .where((t) => !state.unlockedTitles.contains(t))
            .toList();
        final title = available[_rng.nextInt(available.length)];
        return MysteryReward(type: selectedType, title: title);
    }
  }

  void _applyReward(MysteryReward reward) {
    switch (reward.type) {
      case MysteryRewardType.bonusXp:
        // Caller is responsible for adding XP to player service.
        break;

      case MysteryRewardType.streakSaver:
        state = state.copyWith(streakSaverTokens: state.streakSaverTokens + 1);
        break;

      case MysteryRewardType.xpMultiplier:
        state = state.copyWith(pendingMultiplier: reward.value.toDouble());
        break;

      case MysteryRewardType.rarityBoost:
        state = state.copyWith(
          rarityBoostRemaining: state.rarityBoostRemaining + reward.value,
        );
        break;

      case MysteryRewardType.titleUnlock:
        if (reward.title != null) {
          state = state.copyWith(
            unlockedTitles: {...state.unlockedTitles, reward.title!},
          );
        }
        break;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final mysteryRewardProvider =
    StateNotifierProvider<MysteryRewardNotifier, MysteryRewardState>((ref) {
  throw UnimplementedError(
    'mysteryRewardProvider must be overridden after Hive init',
  );
});
