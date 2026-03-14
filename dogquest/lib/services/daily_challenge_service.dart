import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import '../constants.dart';
import '../helpers/date_helpers.dart';

final _log = Logger('DailyChallengeService');

// ─── Challenge Types ─────────────────────────────────────────────────────────

enum ChallengeType {
  identifyDogs,
  findRareDog,
  completeQuiz,
  identifyFamily,
  identifyUnique,
  findLegendary,
  quizPerfect,
}

/// A single daily challenge definition.
class DailyChallenge {
  final String id;
  final ChallengeType type;
  final String title;
  final String description;
  final int target;
  final int xpReward;
  final int progress;
  final bool completed;

  /// Optional parameter for family-based challenges.
  final String? familyId;

  const DailyChallenge({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.target,
    required this.xpReward,
    this.progress = 0,
    this.completed = false,
    this.familyId,
  });

  DailyChallenge copyWith({int? progress, bool? completed}) => DailyChallenge(
        id: id,
        type: type,
        title: title,
        description: description,
        target: target,
        xpReward: xpReward,
        progress: progress ?? this.progress,
        completed: completed ?? this.completed,
        familyId: familyId,
      );

  double get progressFraction => (progress / target).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'title': title,
        'description': description,
        'target': target,
        'xpReward': xpReward,
        'progress': progress,
        'completed': completed,
        'familyId': familyId,
      };

  factory DailyChallenge.fromMap(Map<dynamic, dynamic> map) => DailyChallenge(
        id: map['id'] as String? ?? '',
        type: ChallengeType.values[(map['type'] as int?) ?? 0],
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        target: (map['target'] as num?)?.toInt() ?? 1,
        xpReward: (map['xpReward'] as num?)?.toInt() ?? 50,
        progress: (map['progress'] as num?)?.toInt() ?? 0,
        completed: map['completed'] as bool? ?? false,
        familyId: map['familyId'] as String?,
      );
}

// ─── Weekly Mission ──────────────────────────────────────────────────────────

class WeeklyMission {
  final String id;
  final String title;
  final String description;
  final int target;
  final int xpReward;
  final int progress;
  final bool completed;

  const WeeklyMission({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.xpReward,
    this.progress = 0,
    this.completed = false,
  });

  WeeklyMission copyWith({int? progress, bool? completed}) => WeeklyMission(
        id: id,
        title: title,
        description: description,
        target: target,
        xpReward: xpReward,
        progress: progress ?? this.progress,
        completed: completed ?? this.completed,
      );

  double get progressFraction => (progress / target).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'target': target,
        'xpReward': xpReward,
        'progress': progress,
        'completed': completed,
      };

  factory WeeklyMission.fromMap(Map<dynamic, dynamic> map) => WeeklyMission(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        target: (map['target'] as num?)?.toInt() ?? 1,
        xpReward: (map['xpReward'] as num?)?.toInt() ?? 500,
        progress: (map['progress'] as num?)?.toInt() ?? 0,
        completed: map['completed'] as bool? ?? false,
      );
}

// ─── Challenge State ─────────────────────────────────────────────────────────

class DailyChallengeState {
  final List<DailyChallenge> challenges;
  final WeeklyMission? weeklyMission;
  final String dateKey;
  final String weekKey;
  final bool dailySweepClaimed;

  const DailyChallengeState({
    this.challenges = const [],
    this.weeklyMission,
    this.dateKey = '',
    this.weekKey = '',
    this.dailySweepClaimed = false,
  });

  DailyChallengeState copyWith({
    List<DailyChallenge>? challenges,
    WeeklyMission? weeklyMission,
    String? dateKey,
    String? weekKey,
    bool? dailySweepClaimed,
  }) =>
      DailyChallengeState(
        challenges: challenges ?? this.challenges,
        weeklyMission: weeklyMission ?? this.weeklyMission,
        dateKey: dateKey ?? this.dateKey,
        weekKey: weekKey ?? this.weekKey,
        dailySweepClaimed: dailySweepClaimed ?? this.dailySweepClaimed,
      );

  bool get allDailyCompleted =>
      challenges.isNotEmpty && challenges.every((c) => c.completed);

  int get completedDailyCount => challenges.where((c) => c.completed).length;

  int get totalDailyXp =>
      challenges.where((c) => c.completed).fold(0, (s, c) => s + c.xpReward);

  /// Total XP available if all daily + sweep completed.
  static const dailySweepBonus = 300;
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class DailyChallengeNotifier extends StateNotifier<DailyChallengeState> {
  static const _boxName = 'dogquest_daily_challenges';
  late Box _box;
  bool _initialized = false;

  DailyChallengeNotifier() : super(const DailyChallengeState());

  /// Public read-only access to the current state (avoids @protected warning).
  DailyChallengeState get currentState => state;

  /// Must call after construction to open the Hive box and load state.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _initialized = true;
    _ensureFreshChallenges();
    _ensureFreshWeeklyMission();
    _log.info(
        'Daily challenges loaded for ${state.dateKey}: ${state.challenges.length} challenges');
  }

  // ─── Daily Challenge Rotation ────────────────────────────────────────

  void _ensureFreshChallenges() {
    final todayKey = formatDateKey(DateTime.now());
    final storedDate = _box.get('daily_date', defaultValue: '') as String;

    if (storedDate == todayKey) {
      // Load existing challenges
      final stored = _box.get('daily_challenges', defaultValue: <dynamic>[]) as List;
      final challenges = stored
          .map((e) => DailyChallenge.fromMap(Map<dynamic, dynamic>.from(e as Map)))
          .toList();
      final swept =
          _box.get('daily_sweep_claimed', defaultValue: false) as bool;
      state = state.copyWith(
        challenges: challenges,
        dateKey: todayKey,
        dailySweepClaimed: swept,
      );
    } else {
      // Generate new challenges for today
      final challenges = _generateDailyChallenges(todayKey);
      state = state.copyWith(
        challenges: challenges,
        dateKey: todayKey,
        dailySweepClaimed: false,
      );
      _saveDailyChallenges();
    }
  }

  List<DailyChallenge> _generateDailyChallenges(String dateKey) {
    // Use the date as a seed for deterministic but rotating challenges
    final seed = dateKey.hashCode;
    final rng = Random(seed);

    final familyNames = [
      'Sporting Group',
      'Hound Group',
      'Working Group',
      'Terrier Group',
      'Toy Group',
      'Non-Sporting Group',
      'Herding Group',
    ];
    final familyIds = [
      'sporting',
      'hound',
      'working',
      'terrier',
      'toy',
      'non_sporting',
      'herding',
    ];

    final familyIndex = rng.nextInt(familyNames.length);

    final pool = <DailyChallenge>[
      DailyChallenge(
        id: '${dateKey}_identify_3',
        type: ChallengeType.identifyDogs,
        title: 'Spot 3 Dogs',
        description: 'Identify 3 dogs using the camera',
        target: 3,
        xpReward: 100,
      ),
      DailyChallenge(
        id: '${dateKey}_identify_5',
        type: ChallengeType.identifyDogs,
        title: 'Spot 5 Dogs',
        description: 'Identify 5 dogs using the camera',
        target: 5,
        xpReward: 150,
      ),
      DailyChallenge(
        id: '${dateKey}_rare',
        type: ChallengeType.findRareDog,
        title: 'Rare Discovery',
        description: 'Find a rare or legendary dog',
        target: 1,
        xpReward: 200,
      ),
      DailyChallenge(
        id: '${dateKey}_quiz',
        type: ChallengeType.completeQuiz,
        title: 'Quiz Master',
        description: 'Complete a quiz with 80%+ accuracy',
        target: 1,
        xpReward: 100,
      ),
      DailyChallenge(
        id: '${dateKey}_family',
        type: ChallengeType.identifyFamily,
        title: '${familyNames[familyIndex]} Explorer',
        description:
            'Identify a dog from the ${familyNames[familyIndex]}',
        target: 1,
        xpReward: 150,
        familyId: familyIds[familyIndex],
      ),
      DailyChallenge(
        id: '${dateKey}_photo2',
        type: ChallengeType.identifyDogs,
        title: 'Snap Happy',
        description: 'Identify 2 dogs using photo',
        target: 2,
        xpReward: 150,
      ),
      DailyChallenge(
        id: '${dateKey}_unique_3',
        type: ChallengeType.identifyUnique,
        title: 'Variety Hour',
        description: 'Identify 3 different species today',
        target: 3,
        xpReward: 150,
      ),
      DailyChallenge(
        id: '${dateKey}_quiz_perfect',
        type: ChallengeType.quizPerfect,
        title: 'Perfectionist',
        description: 'Score 100% on a quiz',
        target: 1,
        xpReward: 200,
      ),
    ];

    // Shuffle and pick 3 unique types
    pool.shuffle(rng);
    final selected = <DailyChallenge>[];
    final usedTypes = <ChallengeType>{};
    for (final c in pool) {
      if (!usedTypes.contains(c.type)) {
        selected.add(c);
        usedTypes.add(c.type);
      }
      if (selected.length == 3) break;
    }

    return selected;
  }

  void _saveDailyChallenges() {
    if (!_initialized) return;
    _box.put('daily_date', state.dateKey);
    _box.put(
      'daily_challenges',
      state.challenges.map((c) => c.toMap()).toList(),
    );
    _box.put('daily_sweep_claimed', state.dailySweepClaimed);
  }

  // ─── Weekly Mission Rotation ─────────────────────────────────────────

  String _currentWeekKey() {
    final now = DateTime.now();
    // ISO week: week starts on Monday
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return formatDateKey(monday);
  }

  void _ensureFreshWeeklyMission() {
    final weekKey = _currentWeekKey();
    final storedWeek = _box.get('weekly_key', defaultValue: '') as String;

    if (storedWeek == weekKey) {
      final stored = _box.get('weekly_mission');
      if (stored != null) {
        state = state.copyWith(
          weeklyMission:
              WeeklyMission.fromMap(Map<dynamic, dynamic>.from(stored as Map)),
          weekKey: weekKey,
        );
      }
    } else {
      final mission = _generateWeeklyMission(weekKey);
      state = state.copyWith(weeklyMission: mission, weekKey: weekKey);
      _saveWeeklyMission();
    }
  }

  WeeklyMission _generateWeeklyMission(String weekKey) {
    final seed = weekKey.hashCode;
    final rng = Random(seed);

    final pool = <WeeklyMission>[
      WeeklyMission(
        id: '${weekKey}_unique_10',
        title: 'Species Collector',
        description: 'Identify 10 unique species this week',
        target: 10,
        xpReward: 750,
      ),
      WeeklyMission(
        id: '${weekKey}_families_5',
        title: 'Family Explorer',
        description: 'Identify dogs from 5 different groups this week',
        target: 5,
        xpReward: 800,
      ),
      WeeklyMission(
        id: '${weekKey}_streak_5',
        title: 'Dedication',
        description: 'Maintain a 5-day identification streak',
        target: 5,
        xpReward: 500,
      ),
      WeeklyMission(
        id: '${weekKey}_sightings_20',
        title: 'Avid Doger',
        description: 'Log 20 dog sightings this week',
        target: 20,
        xpReward: 600,
      ),
      WeeklyMission(
        id: '${weekKey}_rare_3',
        title: 'Rare Week',
        description: 'Find 3 rare or legendary breeds this week',
        target: 3,
        xpReward: 1000,
      ),
      WeeklyMission(
        id: '${weekKey}_quizzes_5',
        title: 'Study Week',
        description: 'Complete 5 quizzes this week',
        target: 5,
        xpReward: 500,
      ),
    ];

    return pool[rng.nextInt(pool.length)];
  }

  void _saveWeeklyMission() {
    if (!_initialized) return;
    _box.put('weekly_key', state.weekKey);
    final mission = state.weeklyMission;
    if (mission != null) {
      _box.put('weekly_mission', mission.toMap());
    }
  }

  // ─── Progress Recording (called by other services) ───────────────────

  /// Record a dog identification. Called after a successful ML or audio ID.
  /// [dogRarity] is the identified dog's rarity tier.
  /// [familyId] is the dog's family id (nullable).
  /// [source] is 'ml' or 'audio'.
  /// Returns XP earned from completed challenges.
  int recordIdentification({
    required Rarity dogRarity,
    String? familyId,
    String source = 'ml',
  }) {
    _ensureDateFresh();
    int xpEarned = 0;
    final updated = List<DailyChallenge>.from(state.challenges);

    for (int i = 0; i < updated.length; i++) {
      final c = updated[i];
      if (c.completed) continue;

      bool shouldProgress = false;

      switch (c.type) {
        case ChallengeType.identifyDogs:
          shouldProgress = true;
          break;
        case ChallengeType.findRareDog:
          shouldProgress = dogRarity == Rarity.rare ||
              dogRarity == Rarity.legendary;
          break;
        case ChallengeType.findLegendary:
          shouldProgress = dogRarity == Rarity.legendary;
          break;
        case ChallengeType.identifyFamily:
          shouldProgress =
              familyId != null && c.familyId == familyId;
          break;
        case ChallengeType.identifyUnique:
          // Unique tracking — increment per identification, dedupe is caller's
          // responsibility (pass only for new species today).
          shouldProgress = true;
          break;
        default:
          break;
      }

      if (shouldProgress) {
        final newProgress = min(c.progress + 1, c.target);
        final nowComplete = newProgress >= c.target;
        updated[i] = c.copyWith(
          progress: newProgress,
          completed: nowComplete,
        );
        if (nowComplete && !c.completed) {
          xpEarned += c.xpReward;
          _log.info('Daily challenge completed: ${c.title} (+${c.xpReward} XP)');
        }
      }
    }

    state = state.copyWith(challenges: updated);
    _saveDailyChallenges();

    // Check weekly mission progress for identification-based missions
    _progressWeeklyForIdentification(dogRarity, familyId);

    return xpEarned;
  }

  /// Record a quiz completion. Returns XP earned from completed challenges.
  int recordQuiz({required int score, required int total}) {
    _ensureDateFresh();
    int xpEarned = 0;
    final updated = List<DailyChallenge>.from(state.challenges);
    final percentage = total > 0 ? (score / total * 100) : 0;

    for (int i = 0; i < updated.length; i++) {
      final c = updated[i];
      if (c.completed) continue;

      bool shouldProgress = false;

      switch (c.type) {
        case ChallengeType.completeQuiz:
          shouldProgress = percentage >= 80;
          break;
        case ChallengeType.quizPerfect:
          shouldProgress = score == total;
          break;
        default:
          break;
      }

      if (shouldProgress) {
        final newProgress = min(c.progress + 1, c.target);
        final nowComplete = newProgress >= c.target;
        updated[i] = c.copyWith(
          progress: newProgress,
          completed: nowComplete,
        );
        if (nowComplete && !c.completed) {
          xpEarned += c.xpReward;
          _log.info(
              'Daily challenge completed: ${c.title} (+${c.xpReward} XP)');
        }
      }
    }

    state = state.copyWith(challenges: updated);
    _saveDailyChallenges();

    // Weekly quiz missions
    _progressWeeklyForQuiz();

    return xpEarned;
  }

  /// Claim the daily sweep bonus. Returns XP awarded (0 if not eligible).
  int claimDailySweep() {
    if (!state.allDailyCompleted || state.dailySweepClaimed) return 0;
    state = state.copyWith(dailySweepClaimed: true);
    _saveDailyChallenges();
    _log.info(
        'Daily Sweep claimed! +${DailyChallengeState.dailySweepBonus} XP + streak saver');
    return DailyChallengeState.dailySweepBonus;
  }

  /// Whether the daily sweep bonus is ready to claim.
  bool get canClaimDailySweep =>
      state.allDailyCompleted && !state.dailySweepClaimed;

  // ─── Weekly Progress ─────────────────────────────────────────────────

  void _progressWeeklyForIdentification(Rarity rarity, String? familyId) {
    final mission = state.weeklyMission;
    if (mission == null || mission.completed) return;

    bool shouldProgress = false;

    if (mission.id.contains('unique_') || mission.id.contains('sightings_')) {
      shouldProgress = true;
    } else if (mission.id.contains('rare_')) {
      shouldProgress =
          rarity == Rarity.rare || rarity == Rarity.legendary;
    } else if (mission.id.contains('families_')) {
      // For family-based weekly missions, only progress if familyId is set
      shouldProgress = familyId != null;
    }

    if (shouldProgress) {
      final newProgress = min(mission.progress + 1, mission.target);
      final nowComplete = newProgress >= mission.target;
      state = state.copyWith(
        weeklyMission: mission.copyWith(
          progress: newProgress,
          completed: nowComplete,
        ),
      );
      _saveWeeklyMission();
      if (nowComplete) {
        _log.info(
            'Weekly mission completed: ${mission.title} (+${mission.xpReward} XP)');
      }
    }
  }

  void _progressWeeklyForQuiz() {
    final mission = state.weeklyMission;
    if (mission == null || mission.completed) return;

    if (mission.id.contains('quizzes_')) {
      final newProgress = min(mission.progress + 1, mission.target);
      final nowComplete = newProgress >= mission.target;
      state = state.copyWith(
        weeklyMission: mission.copyWith(
          progress: newProgress,
          completed: nowComplete,
        ),
      );
      _saveWeeklyMission();
      if (nowComplete) {
        _log.info(
            'Weekly mission completed: ${mission.title} (+${mission.xpReward} XP)');
      }
    }
  }

  /// Record streak progress for streak-based weekly missions.
  void recordStreakDay(int currentStreak) {
    final mission = state.weeklyMission;
    if (mission == null || mission.completed) return;

    if (mission.id.contains('streak_')) {
      if (currentStreak > mission.progress) {
        final newProgress = min(currentStreak, mission.target);
        final nowComplete = newProgress >= mission.target;
        state = state.copyWith(
          weeklyMission: mission.copyWith(
            progress: newProgress,
            completed: nowComplete,
          ),
        );
        _saveWeeklyMission();
      }
    }
  }

  /// Claim weekly mission reward. Returns XP (0 if not eligible).
  int claimWeeklyMission() {
    final mission = state.weeklyMission;
    if (mission == null || !mission.completed) return 0;
    // Mark as claimed by setting progress beyond target (or just return the XP)
    // The mission stays completed — it won't reset until next week.
    _log.info('Weekly mission claimed: ${mission.title} (+${mission.xpReward} XP)');
    return mission.xpReward;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  /// If the date has changed since state was loaded, refresh challenges.
  void _ensureDateFresh() {
    final todayKey = formatDateKey(DateTime.now());
    if (state.dateKey != todayKey) {
      _ensureFreshChallenges();
    }
    final weekKey = _currentWeekKey();
    if (state.weekKey != weekKey) {
      _ensureFreshWeeklyMission();
    }
  }

  /// Days remaining until the weekly mission resets (next Monday).
  int get daysUntilWeeklyReset {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    return daysUntilMonday == 0 ? 7 : daysUntilMonday;
  }

  /// Time remaining until daily challenges reset (midnight).
  Duration get timeUntilDailyReset {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final dailyChallengeProvider =
    StateNotifierProvider<DailyChallengeNotifier, DailyChallengeState>((ref) {
  throw UnimplementedError(
      'dailyChallengeProvider must be overridden after Hive init');
});
