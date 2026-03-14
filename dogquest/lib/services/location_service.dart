import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:geolocator/geolocator.dart';

final _log = Logger('LocationService');

/// Lightweight GPS service that caches the device's last known location.
///
/// Designed for geographic species filtering — we only need coarse coordinates
/// (city-level accuracy is fine). The location is cached and refreshed at most
/// once every 10 minutes to avoid battery drain.
class LocationService {
  Position? _cached;
  DateTime? _lastFetch;

  /// How long to cache GPS coordinates before re-querying.
  static const _cacheDuration = Duration(minutes: 10);

  /// Current cached latitude, or null if unavailable.
  double? get latitude => _cached?.latitude;

  /// Current cached longitude, or null if unavailable.
  double? get longitude => _cached?.longitude;

  /// Current cached accuracy in meters, or null if unavailable.
  double? get accuracy => _cached?.accuracy;

  /// Whether we have a valid cached position.
  bool get hasLocation => _cached != null;

  /// Get the current location, using cache if fresh enough.
  ///
  /// Returns null gracefully if:
  ///   - Location services are disabled on the device
  ///   - Permission is denied (does NOT prompt — call [requestPermission] first)
  ///   - GPS fails for any reason
  Future<Position?> getLocation() async {
    // Return cache if fresh
    if (_cached != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cached;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _log.info('Location services disabled');
        return _cached; // return stale cache or null
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Don't auto-request here — let the UI handle permission prompts
        _log.info('Location permission not yet granted');
        return _cached;
      }
      if (permission == LocationPermission.deniedForever) {
        _log.info('Location permission permanently denied');
        return _cached;
      }

      // Use low accuracy (coarse) to save battery — we only need region-level
      _cached = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _lastFetch = DateTime.now();
      _log.info('GPS location: ${_cached!.latitude.toStringAsFixed(2)}, '
          '${_cached!.longitude.toStringAsFixed(2)}');
      return _cached;
    } catch (e) {
      _log.warning('GPS location failed: $e');
      return _cached; // return stale cache or null
    }
  }

  /// Request location permission from the user.
  ///
  /// Returns true if permission was granted (either already or just now).
  /// Call this once from the UI before relying on [getLocation].
  Future<bool> requestPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        return true;
      }
      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      _log.warning('Permission request failed: $e');
      return false;
    }
  }

  /// Force-refresh the cached location (ignores cache duration).
  Future<Position?> refresh() async {
    _lastFetch = null;
    return getLocation();
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
