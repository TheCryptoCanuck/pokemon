import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dogquest/services/location_service.dart';

final _log = Logger('DeviceTokenService');

/// Service for managing FCM device tokens and syncing to Supabase for push fan-out.
///
/// Handles:
/// - Retrieving the FCM token from Firebase Messaging
/// - Upserting token + platform + location to the `device_tokens` table
/// - Listening for token refresh events and re-syncing
/// - Optionally including the user's last known location
class DeviceTokenService {
  final SupabaseClient _client;
  final LocationService _locationSvc;

  DeviceTokenService(this._client, this._locationSvc);

  /// Register the device token and listen for future refreshes.
  ///
  /// Call this once during app initialization (e.g., after auth is confirmed).
  Future<void> register() async {
    try {
      // Get current FCM token
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        _log.warning('No FCM token available');
        return;
      }

      // Upsert token to Supabase
      await _upsert(token);

      // Listen for token refresh
      listenForRefresh();

      _log.info('Device token registered and listener started');
    } catch (e) {
      _log.warning('Failed to register device token: $e');
    }
  }

  /// Upsert the token to the device_tokens table.
  ///
  /// Includes platform (android/ios) and optional location data.
  Future<void> _upsert(String token) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _log.warning('No authenticated user; skipping token upsert');
        return;
      }

      // Get user's last known location (may be null)
      double? lat;
      double? lon;
      try {
        final position = await _locationSvc.getLocation();
        lat = position?.latitude;
        lon = position?.longitude;
      } catch (e) {
        _log.finest('Location not available: $e');
      }

      // Determine platform
      final platform = Platform.isAndroid ? 'android' : 'ios';

      // Build upsert payload
      final payload = {
        'user_id': user.id,
        'token': token,
        'platform': platform,
        'last_seen_lat': lat,
        'last_seen_lon': lon,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client
          .from('device_tokens')
          .upsert(
            payload,
            onConflict: 'user_id,token',
          )
          .then((_) {
        _log.info(
          'Token upserted (platform: $platform, location: ${lat != null ? "($lat, $lon)" : "unavailable"})',
        );
      });
    } catch (e) {
      _log.warning('Failed to upsert device token: $e');
      rethrow;
    }
  }

  /// Listen for FCM token refresh and re-sync to Supabase.
  ///
  /// Attach this listener after initial registration. It will re-upsert
  /// the token whenever Firebase rotates it.
  void listenForRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        _log.info('FCM token refreshed');
        try {
          await _upsert(newToken);
        } catch (e) {
          _log.warning('Failed to upsert refreshed token: $e');
        }
      },
      onError: (error) {
        _log.warning('Error listening to token refresh: $error');
      },
    );
  }
}

/// Riverpod provider for DeviceTokenService.
///
/// Returns null if the user is not authenticated. This provider is typically
/// overridden in main.dart after services are initialized.
final deviceTokenServiceProvider = Provider<DeviceTokenService?>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;

  final locationSvc = ref.watch(locationServiceProvider);
  return DeviceTokenService(Supabase.instance.client, locationSvc);
});
