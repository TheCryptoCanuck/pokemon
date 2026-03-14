import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('AnalyticsService');

/// Dual analytics: local Hive storage + Firebase Analytics.
///
/// Local Hive box stores events for offline debugging/export.
/// Firebase Analytics forwards events for real-time dashboards
/// and investor-facing metrics. Firebase is best-effort — if not
/// initialized (missing google-services.json), events are local only.
class AnalyticsService {
  static const _boxName = 'dogquest_analytics_events';
  static const maxEvents = 10000;

  late Box _box;
  int _sessionNumber = 0;
  FirebaseAnalytics? _firebase;

  int get sessionNumber => _sessionNumber;

  Future<void> init({FirebaseAnalytics? firebaseAnalytics}) async {
    _box = await Hive.openBox(_boxName);
    _sessionNumber = _box.get('_meta_session_count', defaultValue: 0) as int;
    _sessionNumber++;
    await _box.put('_meta_session_count', _sessionNumber);

    _firebase = firebaseAnalytics;
    if (_firebase != null) {
      _firebase!.setUserProperty(name: 'session_number', value: '$_sessionNumber');
      _log.info('Analytics initialised with Firebase (session #$_sessionNumber)');
    } else {
      _log.info('Analytics initialised local-only (session #$_sessionNumber, ${_box.length} stored events)');
    }
  }

  /// Log an event with optional properties.
  void track(String event, [Map<String, dynamic>? properties]) {
    // Local Hive storage
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
      keysToDelete.remove('_meta_session_count');
      _box.deleteAll(keysToDelete);
    }

    // Firebase Analytics (best-effort)
    if (_firebase != null) {
      // Firebase event names: lowercase, underscores, max 40 chars
      final fbEvent = event.length > 40 ? event.substring(0, 40) : event;
      final fbParams = <String, Object>{};
      if (properties != null) {
        for (final e in properties.entries) {
          // Firebase param values must be String, int, or double
          final v = e.value;
          if (v is String || v is int || v is double || v is bool) {
            fbParams[e.key] = v is bool ? (v ? 1 : 0) : v;
          } else if (v != null) {
            fbParams[e.key] = v.toString();
          }
        }
      }
      _firebase!.logEvent(name: fbEvent, parameters: fbParams.isEmpty ? null : fbParams);
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
