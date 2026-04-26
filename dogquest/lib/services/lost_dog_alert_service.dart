import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import '../models/lost_dog_report.dart';
import 'location_service.dart';
import 'lost_dog_service.dart';

final _log = Logger('LostDogAlertService');

/// Proximity-based alert service for the Lost Dog Recognition Network.
///
/// Checks if the user is near any active lost dog reports and fires
/// local notifications to encourage community awareness. Uses haversine
/// distance and tracks already-alerted report IDs in a persistent Hive map
/// to prevent spam across app restarts. Re-alerts are suppressed for 72 hours.
class LostDogAlertService {
  final LostDogService _lostDogSvc;
  final LocationService _locationSvc;
  final Box<int> _alertedBox;

  static const _alertRadiusKm = 2.0;
  static const _alertExpiryMs = 72 * 60 * 60 * 1000; // 72 hours
  static const _channelId = 'dogquest_lost_dog_alerts';
  static const _channelName = 'Lost Dog Alerts';
  static const _baseNotificationId = 2000;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  LostDogAlertService(
    this._lostDogSvc,
    this._locationSvc,
    this._alertedBox,
  );

  /// Check proximity to all active lost dog reports.
  ///
  /// Returns the list of active reports within [_alertRadiusKm] of the
  /// user's current location. Returns an empty list if location is
  /// unavailable or no reports are nearby.
  Future<List<LostDogReport>> checkProximity() async {
    final position = await _locationSvc.getLocation();
    if (position == null) {
      _log.info('No location available — skipping proximity check');
      return [];
    }

    final userLat = position.latitude;
    final userLon = position.longitude;
    final nearby = <LostDogReport>[];

    for (final report in _lostDogSvc.activeReports) {
      if (report.lastSeenLat == null || report.lastSeenLon == null) continue;

      final dist = _haversineKm(
        userLat,
        userLon,
        report.lastSeenLat!,
        report.lastSeenLon!,
      );

      if (dist <= _alertRadiusKm) {
        nearby.add(report);
      }
    }

    _log.info('Proximity check: ${nearby.length} report(s) within '
        '$_alertRadiusKm km');
    return nearby;
  }

  /// Fire local notifications for nearby lost dogs.
  ///
  /// Skips reports that have already been alerted within the last 72 hours
  /// to avoid notification spam. Prunes stale entries at the start to prevent
  /// unbounded growth. Each notification gets a unique ID derived from
  /// [_baseNotificationId] + index so they don't overwrite each other.
  Future<void> alertNearbyLostDogs() async {
    // Prune stale entries (> 72 hours old)
    await _pruneStaleAlerts();

    final position = await _locationSvc.getLocation();
    if (position == null) {
      _log.info('No location — cannot alert nearby lost dogs');
      return;
    }

    final userLat = position.latitude;
    final userLon = position.longitude;
    var notificationIndex = 0;

    for (final report in _lostDogSvc.activeReports) {
      if (report.lastSeenLat == null || report.lastSeenLon == null) continue;

      // Skip already-alerted reports (within 72 hours)
      if (hasAlerted(report.id)) continue;

      final dist = _haversineKm(
        userLat,
        userLon,
        report.lastSeenLat!,
        report.lastSeenLon!,
      );

      if (dist <= _alertRadiusKm) {
        final distStr = dist < 1.0
            ? '${(dist * 1000).round()} m'
            : '${dist.toStringAsFixed(1)} km';

        final daysAgo = DateTime.now().difference(report.lostDate).inDays;
        final daysStr = daysAgo == 0
            ? 'today'
            : daysAgo == 1
                ? '1 day ago'
                : '$daysAgo days ago';

        final breedLabel = report.breed ?? 'dog';

        await _plugin.show(
          _baseNotificationId + notificationIndex,
          'Lost Dog Alert',
          'A $breedLabel named ${report.dogName} was lost $distStr away '
              '$daysStr. Keep an eye out!',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription:
                  'Alerts when you are near a reported lost dog',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: 'lost_dog_${report.id}',
        );

        // Record the alert timestamp in Hive
        await _alertedBox.put(
          report.id,
          DateTime.now().millisecondsSinceEpoch,
        );
        notificationIndex++;

        _log.info('Alert fired for lost dog "${report.dogName}" '
            '($distStr away)');
      }
    }

    if (notificationIndex > 0) {
      _log.info('Fired $notificationIndex notification(s)');
    }
  }

  /// Clear the persisted alert history, allowing repeat alerts immediately.
  ///
  /// Useful when the user navigates to the lost dog hub or manually
  /// resets the alert state.
  Future<void> resetAlerts() async {
    await _alertedBox.clear();
    _log.info('Alert history cleared');
  }

  /// Whether a specific report has already been alerted within 72 hours.
  ///
  /// Returns true if the report ID is in the box and the stored timestamp
  /// is recent (< 72 hours old). Returns false if the report is not in the
  /// box or the alert has expired.
  bool hasAlerted(String reportId) {
    final timestampMs = _alertedBox.get(reportId);
    if (timestampMs == null) return false;

    final age = DateTime.now().millisecondsSinceEpoch - timestampMs;
    return age < _alertExpiryMs;
  }

  /// Prune alert entries older than 72 hours to prevent unbounded growth.
  Future<void> _pruneStaleAlerts() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final keysToDelete = <String>[];

    for (final key in _alertedBox.keys) {
      final timestampMs = _alertedBox.get(key);
      if (timestampMs != null) {
        final age = now - timestampMs;
        if (age >= _alertExpiryMs) {
          keysToDelete.add(key as String);
        }
      }
    }

    if (keysToDelete.isNotEmpty) {
      await _alertedBox.deleteAll(keysToDelete);
      _log.info('Pruned ${keysToDelete.length} stale alert(s)');
    }
  }

  /// Haversine formula for distance between two GPS coordinates (in km).
  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provides [LostDogAlertService]. Must be overridden after Hive and
/// [LostDogService] are both initialised in main.dart.
final lostDogAlertServiceProvider = Provider<LostDogAlertService>((ref) {
  throw UnimplementedError(
    'lostDogAlertServiceProvider must be overridden after Hive init',
  );
});
