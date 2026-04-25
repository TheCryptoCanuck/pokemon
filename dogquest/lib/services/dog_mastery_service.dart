import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('DogMasteryService');

// ─── Mastery Level ───────────────────────────────────────────────────────────

enum DogMasteryLevel {
  unseen,
  spotted, // 1 sighting
  familiar, // 3 sightings
  expert, // 5 sightings
  master, // 10 sightings
}

extension DogMasteryLevelExt on DogMasteryLevel {
  String get label {
    switch (this) {
      case DogMasteryLevel.unseen:
        return 'Unseen';
      case DogMasteryLevel.spotted:
        return 'Spotted';
      case DogMasteryLevel.familiar:
        return 'Familiar';
      case DogMasteryLevel.expert:
        return 'Expert';
      case DogMasteryLevel.master:
        return 'Master';
    }
  }

  int get requiredSightings {
    switch (this) {
      case DogMasteryLevel.unseen:
        return 0;
      case DogMasteryLevel.spotted:
        return 1;
      case DogMasteryLevel.familiar:
        return 3;
      case DogMasteryLevel.expert:
        return 5;
      case DogMasteryLevel.master:
        return 10;
    }
  }

  /// XP bonus awarded when reaching this mastery level.
  int get xpBonus {
    switch (this) {
      case DogMasteryLevel.unseen:
        return 0;
      case DogMasteryLevel.spotted:
        return 25;
      case DogMasteryLevel.familiar:
        return 75;
      case DogMasteryLevel.expert:
        return 150;
      case DogMasteryLevel.master:
        return 300;
    }
  }

  Color get color {
    switch (this) {
      case DogMasteryLevel.unseen:
        return Colors.white24;
      case DogMasteryLevel.spotted:
        return Colors.white70;
      case DogMasteryLevel.familiar:
        return const Color(0xFFD4874E);
      case DogMasteryLevel.expert:
        return const Color(0xFF2196F3);
      case DogMasteryLevel.master:
        return Colors.amber;
    }
  }

  IconData get icon {
    switch (this) {
      case DogMasteryLevel.unseen:
        return Icons.visibility_off;
      case DogMasteryLevel.spotted:
        return Icons.visibility;
      case DogMasteryLevel.familiar:
        return Icons.star_half;
      case DogMasteryLevel.expert:
        return Icons.star;
      case DogMasteryLevel.master:
        return Icons.workspace_premium;
    }
  }

  /// The next mastery level, or null if already at max.
  DogMasteryLevel? get next {
    final idx = DogMasteryLevel.values.indexOf(this);
    if (idx >= DogMasteryLevel.values.length - 1) return null;
    return DogMasteryLevel.values[idx + 1];
  }
}

// ─── Dog Mastery Info ───────────────────────────────────────────────────────

class DogMasteryInfo {
  final String dogName;
  final int sightingCount;
  final DogMasteryLevel level;

  const DogMasteryInfo({
    required this.dogName,
    required this.sightingCount,
    required this.level,
  });

  /// Progress toward the next mastery level (0.0 - 1.0).
  double get progressToNext {
    final nextLevel = level.next;
    if (nextLevel == null) return 1.0; // Already master
    final currentReq = level.requiredSightings;
    final nextReq = nextLevel.requiredSightings;
    final range = nextReq - currentReq;
    if (range <= 0) return 1.0;
    return ((sightingCount - currentReq) / range).clamp(0.0, 1.0);
  }

  /// Sightings still needed for the next level.
  int get sightingsToNextLevel {
    final nextLevel = level.next;
    if (nextLevel == null) return 0;
    return max(0, nextLevel.requiredSightings - sightingCount);
  }

  bool get isMastered => level == DogMasteryLevel.master;
}

// ─── Service State ───────────────────────────────────────────────────────────

class DogMasteryState {
  final Map<String, int> sightingCounts;

  const DogMasteryState({this.sightingCounts = const {}});

  DogMasteryState copyWith({Map<String, int>? sightingCounts}) =>
      DogMasteryState(
        sightingCounts: sightingCounts ?? this.sightingCounts,
      );

  DogMasteryLevel levelFor(String dogName) {
    final count = sightingCounts[dogName] ?? 0;
    return _levelFromCount(count);
  }

  DogMasteryInfo infoFor(String dogName) {
    final count = sightingCounts[dogName] ?? 0;
    return DogMasteryInfo(
      dogName: dogName,
      sightingCount: count,
      level: _levelFromCount(count),
    );
  }

  int get totalMastered => sightingCounts.values.where((c) => c >= 10).length;

  int get totalExpert => sightingCounts.values.where((c) => c >= 5).length;

  int get totalFamiliar => sightingCounts.values.where((c) => c >= 3).length;

  int get totalSpotted => sightingCounts.values.where((c) => c >= 1).length;

  /// All dogs that have reached mastery level.
  List<String> get masteredDogs => sightingCounts.entries
      .where((e) => e.value >= 10)
      .map((e) => e.key)
      .toList();

  static DogMasteryLevel _levelFromCount(int count) {
    if (count >= 10) return DogMasteryLevel.master;
    if (count >= 5) return DogMasteryLevel.expert;
    if (count >= 3) return DogMasteryLevel.familiar;
    if (count >= 1) return DogMasteryLevel.spotted;
    return DogMasteryLevel.unseen;
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class DogMasteryNotifier extends StateNotifier<DogMasteryState> {
  static const _boxName = 'dogquest_mastery';
  late Box<int> _box;
  bool _initialized = false;

  DogMasteryNotifier() : super(const DogMasteryState());

  /// Initialize the Hive box and load persisted mastery data.
  Future<void> init() async {
    _box = await Hive.openBox<int>(_boxName);
    _initialized = true;
    _load();
    _log.info(
        'Dog mastery loaded: ${state.sightingCounts.length} dogs tracked');
  }

  /// Reload mastery state from Hive. Used by demo mode to pick up
  /// externally-written data without restarting the app.
  void reload() => _load();

  void _load() {
    final counts = <String, int>{};
    for (final key in _box.keys) {
      counts[key as String] = _box.get(key, defaultValue: 0)!;
    }
    state = DogMasteryState(sightingCounts: counts);
  }

  /// Record a sighting of a dog. Returns the XP bonus if a new mastery
  /// level was reached, or 0 if no level change occurred.
  ///
  /// Also returns the new [DogMasteryLevel] via the record type.
  ({int xpBonus, DogMasteryLevel level, DogMasteryLevel? previousLevel})
      recordSighting(String dogName) {
    if (!_initialized) {
      return (
        xpBonus: 0,
        level: DogMasteryLevel.unseen,
        previousLevel: null,
      );
    }

    final oldCount = state.sightingCounts[dogName] ?? 0;
    final oldLevel = DogMasteryState._levelFromCount(oldCount);
    final newCount = oldCount + 1;
    final newLevel = DogMasteryState._levelFromCount(newCount);

    // Update state
    final updated = Map<String, int>.from(state.sightingCounts);
    updated[dogName] = newCount;
    state = state.copyWith(sightingCounts: updated);

    // Persist
    _box.put(dogName, newCount);

    // Calculate XP bonus for level-up
    int xpBonus = 0;
    if (newLevel != oldLevel) {
      xpBonus = newLevel.xpBonus;
      _log.info(
          'Dog mastery level up: $dogName -> ${newLevel.label} (+$xpBonus XP)');
    }

    return (
      xpBonus: xpBonus,
      level: newLevel,
      previousLevel: newLevel != oldLevel ? oldLevel : null,
    );
  }

  /// Get mastery info for a specific dog.
  DogMasteryInfo infoFor(String dogName) => state.infoFor(dogName);

  /// Get the mastery level for a dog (convenience).
  DogMasteryLevel levelFor(String dogName) => state.levelFor(dogName);

  /// Get mastery info for all tracked dogs, sorted by sighting count desc.
  List<DogMasteryInfo> get allTracked {
    final entries = state.sightingCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) => DogMasteryInfo(
              dogName: e.key,
              sightingCount: e.value,
              level: DogMasteryState._levelFromCount(e.value),
            ))
        .toList();
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final dogMasteryProvider =
    StateNotifierProvider<DogMasteryNotifier, DogMasteryState>((ref) {
  throw UnimplementedError(
      'dogMasteryProvider must be overridden after Hive init');
});
