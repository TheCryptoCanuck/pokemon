import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:dogquest/helpers/date_helpers.dart';

final _log = Logger('ActivityTrackerService');

/// Tracks daily dog identification counts for the collection heatmap.
///
/// Data is stored in a Hive box named 'activity_tracker' where each key is a
/// date string (YYYY-MM-DD) and the value is the number of identifications
/// recorded that day.
class ActivityTrackerService {
  static const _boxName = 'dogquest_activity_tracker';
  late Box<int> _box;

  /// Open (or reuse) the Hive box. Must be called once at startup.
  Future<void> init() async {
    _box = await Hive.openBox<int>(_boxName);
    _log.info('Activity tracker loaded: ${_box.length} day entries');
  }

  /// Record a single dog identification for today.
  ///
  /// Increments the count for the current date key.
  void recordIdentification() {
    final key = formatDateKey(DateTime.now());
    final current = _box.get(key, defaultValue: 0) ?? 0;
    _box.put(key, current + 1);
    _log.fine('Recorded identification for $key (total: ${current + 1})');
  }

  /// Returns the activity map for the last 84 days (12 weeks).
  ///
  /// Keys are date strings in YYYY-MM-DD format, values are identification
  /// counts. Days with zero identifications are included with a value of 0.
  Map<String, int> getActivityMap() {
    final now = DateTime.now();
    const totalDays = 84; // 12 weeks
    final result = <String, int>{};

    for (int i = totalDays - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = formatDateKey(date);
      result[key] = _box.get(key, defaultValue: 0) ?? 0;
    }

    return result;
  }

  /// Total identifications across all tracked days.
  int get totalIdentifications {
    if (_box.isEmpty) return 0;
    return _box.values.fold<int>(0, (sum, count) => sum + count);
  }

  /// Count for a specific date key.
  int countForDate(String dateKey) => _box.get(dateKey, defaultValue: 0) ?? 0;

  /// The most active day in the last 84 days.
  (String dateKey, int count)? get bestDay {
    final map = getActivityMap();
    if (map.isEmpty) return null;
    final best = map.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    if (best.value == 0) return null;
    return (best.key, best.value);
  }
}

/// Riverpod provider for [ActivityTrackerService].
///
/// Must be overridden in main.dart after calling [ActivityTrackerService.init].
final activityTrackerProvider = Provider<ActivityTrackerService>((ref) {
  throw UnimplementedError(
    'activityTrackerProvider must be overridden after Hive init',
  );
});

/// Convenience provider that exposes the current activity map as a
/// watchable value. Consumers can use `ref.watch(activityMapProvider)`.
final activityMapProvider = Provider<Map<String, int>>((ref) {
  final tracker = ref.watch(activityTrackerProvider);
  return tracker.getActivityMap();
});
