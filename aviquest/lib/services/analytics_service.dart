import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('AnalyticsService');

/// Local event logger backed by a Hive box.
///
/// Stores events as JSON maps with timestamp, event name, and properties.
/// FIFO eviction at [maxEvents] to cap storage. No network calls — purely
/// local for now. A remote sink (Aptabase, etc.) can be wired through the
/// same interface later.
class AnalyticsService {
  static const _boxName = 'analytics_events';
  static const maxEvents = 10000;

  late Box _box;
  int _sessionNumber = 0;

  int get sessionNumber => _sessionNumber;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _sessionNumber = _box.get('_meta_session_count', defaultValue: 0) as int;
    _sessionNumber++;
    await _box.put('_meta_session_count', _sessionNumber);
    _log.info('Analytics initialised (session #$_sessionNumber, ${_box.length} stored events)');
  }

  /// Log an event with optional properties.
  void track(String event, [Map<String, dynamic>? properties]) {
    final entry = <String, dynamic>{
      'event': event,
      'ts': DateTime.now().toIso8601String(),
      'session': _sessionNumber,
      if (properties != null) ...{'props': properties},
    };
    _box.add(entry);

    // FIFO eviction
    if (_box.length > maxEvents + 100) {
      final keysToDelete = _box.keys.take(_box.length - maxEvents).toList();
      // Don't delete the meta key
      keysToDelete.remove('_meta_session_count');
      _box.deleteAll(keysToDelete);
    }

    _log.fine('Event: $event ${properties ?? ''}');
  }

  /// Get all stored events (for debugging / export).
  List<Map> get events =>
      _box.values.whereType<Map>().where((e) => e.containsKey('event')).toList();

  /// Number of stored events.
  int get eventCount => events.length;
}

final analyticsProvider = Provider<AnalyticsService>((ref) {
  throw UnimplementedError('analyticsProvider must be overridden after init');
});
