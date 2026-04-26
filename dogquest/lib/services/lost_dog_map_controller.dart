import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:logging/logging.dart';
import 'supabase_lost_dog_service.dart';

final _log = Logger('LostDogMapController');

/// Owns all remote/async state for the Lost Dog Map screen.
/// Manages cloud report fetching and real-time sighting subscriptions.
class LostDogMapController extends ChangeNotifier {
  List<LostDogReportRemote> _remoteReports = [];
  List<LostDogSightingRemote> _liveSightings = [];
  StreamSubscription<List<LostDogSightingRemote>>? _sightingSub;
  bool _loadingRemote = false;

  List<LostDogReportRemote> get remoteReports => _remoteReports;
  List<LostDogSightingRemote> get liveSightings => _liveSightings;
  bool get loadingRemote => _loadingRemote;

  @override
  void dispose() {
    _sightingSub?.cancel();
    super.dispose();
  }

  /// Fetch active lost dog reports within 80 km of current location.
  Future<void> fetchRemoteReports(
    SupabaseLostDogService? remoteSvc,
  ) async {
    if (remoteSvc == null) return;

    _loadingRemote = true;
    notifyListeners();

    try {
      final position = await geolocator.Geolocator.getCurrentPosition(
        locationSettings: const geolocator.LocationSettings(
          accuracy: geolocator.LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final reports = await remoteSvc.getActiveNearby(
        position.latitude,
        position.longitude,
        radiusKm: 80.0,
      );
      _remoteReports = reports;
      _loadingRemote = false;
      notifyListeners();
    } catch (e, st) {
      // sec-C3: surface geolocator/network failures.
      _log.warning('Failed to fetch remote reports', e, st);
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'lost_dog_map_controller.fetchRemoteReports',
          fatal: false,
        ),
      );
      _loadingRemote = false;
      notifyListeners();
    }
  }

  /// Subscribe to real-time sightings for a specific report.
  void subscribeToSightings(
      String reportId, SupabaseLostDogService? remoteSvc) {
    _sightingSub?.cancel();
    if (remoteSvc == null) return;

    _sightingSub = remoteSvc.watchSightings(reportId).listen((sightings) {
      _liveSightings = sightings;
      notifyListeners();
    });
  }

  /// Clear live sightings and cancel subscription.
  void clearSightings() {
    _sightingSub?.cancel();
    _liveSightings = [];
    notifyListeners();
  }

  /// Fetch user's current position for reporting sightings.
  Future<geolocator.Position?> fetchUserPosition() async {
    try {
      return await geolocator.Geolocator.getCurrentPosition(
        locationSettings: const geolocator.LocationSettings(
          accuracy: geolocator.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e, st) {
      // sec-C3: surface geolocator failures to Crashlytics.
      _log.warning('Failed to get user position', e, st);
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'lost_dog_map_controller.fetchUserPosition',
          fatal: false,
        ),
      );
      return null;
    }
  }
}
