import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger('PlaydateService');

// ─── Data Classes ────────────────────────────────────────────────────────────

/// A playdate event fetched from Supabase.
class PlaydateRemote {
  final String id;
  final String organizerUsername;
  final String? organizerDisplayName;
  final String? organizerDogName;
  final String? organizerDogBreed;
  final String locationName;
  final double lat;
  final double lon;
  final DateTime scheduledAt;
  final int maxDogs;
  final String? description;
  final String status;
  final int rsvpCount;
  final double? distanceMiles;

  const PlaydateRemote({
    required this.id,
    required this.organizerUsername,
    this.organizerDisplayName,
    this.organizerDogName,
    this.organizerDogBreed,
    required this.locationName,
    required this.lat,
    required this.lon,
    required this.scheduledAt,
    this.maxDogs = 5,
    this.description,
    this.status = 'upcoming',
    this.rsvpCount = 0,
    this.distanceMiles,
  });

  factory PlaydateRemote.fromJson(Map<String, dynamic> json,
      {double? distanceMiles}) {
    // Organizer user info may be nested under 'users' join
    final user = json['users'] as Map<String, dynamic>? ?? {};
    // Organizer dog info may be nested under 'dog_profiles' join
    final dog = json['dog_profiles'] as Map<String, dynamic>? ?? {};

    return PlaydateRemote(
      id: json['id'] as String,
      organizerUsername: user['username'] as String? ?? '',
      organizerDisplayName: user['display_name'] as String?,
      organizerDogName: dog['name'] as String?,
      organizerDogBreed: dog['breed'] as String?,
      locationName: json['location_name'] as String? ?? 'Unknown',
      lat: (json['latitude'] as num).toDouble(),
      lon: (json['longitude'] as num).toDouble(),
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      maxDogs: json['max_dogs'] as int? ?? 5,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'upcoming',
      rsvpCount: json['rsvp_count'] as int? ?? 0,
      distanceMiles: distanceMiles,
    );
  }
}

/// An RSVP record for a playdate.
class PlaydateRsvpRemote {
  final String id;
  final String playdateId;
  final String userId;
  final String username;
  final String? displayName;
  final String? dogName;
  final String? dogBreed;
  final String status;

  const PlaydateRsvpRemote({
    required this.id,
    required this.playdateId,
    required this.userId,
    required this.username,
    this.displayName,
    this.dogName,
    this.dogBreed,
    required this.status,
  });

  factory PlaydateRsvpRemote.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>? ?? {};
    final dog = json['dog_profiles'] as Map<String, dynamic>? ?? {};

    return PlaydateRsvpRemote(
      id: json['id'] as String,
      playdateId: json['playdate_id'] as String,
      userId: json['user_id'] as String,
      username: user['username'] as String? ?? '',
      displayName: user['display_name'] as String?,
      dogName: dog['name'] as String?,
      dogBreed: dog['breed'] as String?,
      status: json['status'] as String? ?? 'going',
    );
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class PlaydateService {
  final SupabaseClient _client;

  PlaydateService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  // ── Create ──────────────────────────────────────────────────────────────

  /// Create a new playdate event.
  Future<PlaydateRemote?> createPlaydate({
    required String locationName,
    required double lat,
    required double lon,
    required DateTime scheduledAt,
    int maxDogs = 5,
    String? description,
    String? organizerDogId,
  }) async {
    try {
      final data = {
        'organizer_id': _userId,
        'organizer_dog_id': organizerDogId,
        'location_name': locationName,
        'latitude': lat,
        'longitude': lon,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'max_dogs': maxDogs,
        'description': description,
        'status': 'upcoming',
      };

      final res = await _client
          .from('playdates')
          .insert(data)
          .select('*, users:organizer_id(username, display_name), '
              'dog_profiles:organizer_dog_id(name, breed)')
          .single();

      _log.info('Created playdate ${res['id']}');
      return PlaydateRemote.fromJson(res);
    } catch (e, st) {
      _log.severe('Failed to create playdate', e, st);
      return null;
    }
  }

  // ── Read (nearby) ───────────────────────────────────────────────────────

  /// Fetch upcoming playdates near [lat],[lon] within [radiusMiles].
  /// Performs client-side haversine filtering since Supabase doesn't have
  /// PostGIS enabled.
  Future<List<PlaydateRemote>> getUpcomingNearby(
    double lat,
    double lon, {
    double radiusMiles = 10.0,
  }) async {
    try {
      final rows = await _client
          .from('playdates')
          .select('*, users:organizer_id(username, display_name), '
              'dog_profiles:organizer_dog_id(name, breed), '
              'rsvp_count:playdate_rsvps(count)')
          .eq('status', 'upcoming')
          .gte('scheduled_at', DateTime.now().toUtc().toIso8601String())
          .order('scheduled_at');

      final results = <PlaydateRemote>[];
      for (final row in rows) {
        final pLat = (row['latitude'] as num).toDouble();
        final pLon = (row['longitude'] as num).toDouble();
        final dist = _haversineDistance(lat, lon, pLat, pLon);
        if (dist <= radiusMiles) {
          // Extract count from the aggregate join
          final countList = row['rsvp_count'] as List<dynamic>?;
          final rsvpCount = countList != null && countList.isNotEmpty
              ? (countList.first as Map<String, dynamic>)['count'] as int? ?? 0
              : 0;
          final mapped = Map<String, dynamic>.from(row);
          mapped['rsvp_count'] = rsvpCount;
          mapped.remove('rsvp_count'); // remove list version
          results.add(PlaydateRemote.fromJson(
            {...row, 'rsvp_count': rsvpCount},
            distanceMiles: dist,
          ));
        }
      }

      results.sort(
          (a, b) => (a.distanceMiles ?? 999).compareTo(b.distanceMiles ?? 999));
      _log.info('Found ${results.length} nearby playdates');
      return results;
    } catch (e, st) {
      _log.severe('Failed to fetch nearby playdates', e, st);
      return [];
    }
  }

  // ── RSVP ────────────────────────────────────────────────────────────────

  /// RSVP to a playdate (upsert — going/maybe/declined).
  Future<bool> rsvp(
    String playdateId,
    String? dogId, {
    String status = 'going',
  }) async {
    try {
      await _client.from('playdate_rsvps').upsert(
        {
          'playdate_id': playdateId,
          'user_id': _userId,
          'dog_id': dogId,
          'status': status,
        },
        onConflict: 'playdate_id,dog_id',
      );
      _log.info('RSVP\'d $status to playdate $playdateId');
      return true;
    } catch (e, st) {
      _log.severe('Failed to RSVP', e, st);
      return false;
    }
  }

  /// Cancel (delete) an RSVP.
  Future<bool> cancelRsvp(String playdateId, String? dogId) async {
    try {
      var query = _client
          .from('playdate_rsvps')
          .delete()
          .eq('playdate_id', playdateId)
          .eq('user_id', _userId);
      if (dogId != null) {
        query = query.eq('dog_id', dogId);
      }
      await query;
      _log.info('Cancelled RSVP for playdate $playdateId');
      return true;
    } catch (e, st) {
      _log.severe('Failed to cancel RSVP', e, st);
      return false;
    }
  }

  /// Get all RSVPs for a playdate.
  Future<List<PlaydateRsvpRemote>> getRsvps(String playdateId) async {
    try {
      final rows = await _client
          .from('playdate_rsvps')
          .select('*, users:user_id(username, display_name), '
              'dog_profiles:dog_id(name, breed)')
          .eq('playdate_id', playdateId)
          .order('created_at');

      return rows.map((r) => PlaydateRsvpRemote.fromJson(r)).toList();
    } catch (e, st) {
      _log.severe('Failed to fetch RSVPs', e, st);
      return [];
    }
  }

  // ── My playdates ───────────────────────────────────────────────────────

  /// Playdates where the current user is the organizer OR has RSVP'd.
  Future<List<PlaydateRemote>> getMyPlaydates() async {
    try {
      // Fetch organized playdates
      final organized = await _client
          .from('playdates')
          .select('*, users:organizer_id(username, display_name), '
              'dog_profiles:organizer_dog_id(name, breed)')
          .eq('organizer_id', _userId)
          .order('scheduled_at', ascending: false);

      // Fetch RSVP'd playdates
      final rsvps = await _client
          .from('playdate_rsvps')
          .select('playdate_id')
          .eq('user_id', _userId);

      final rsvpIds = rsvps.map((r) => r['playdate_id'] as String).toSet();

      // Remove any organized ones from rsvp set to avoid duplicates
      final organizedIds = organized.map((r) => r['id'] as String).toSet();
      final extraIds = rsvpIds.difference(organizedIds);

      List<Map<String, dynamic>> rsvpPlaydates = [];
      if (extraIds.isNotEmpty) {
        rsvpPlaydates = await _client
            .from('playdates')
            .select('*, users:organizer_id(username, display_name), '
                'dog_profiles:organizer_dog_id(name, breed)')
            .inFilter('id', extraIds.toList())
            .order('scheduled_at', ascending: false);
      }

      final all = [
        ...organized.map((r) => PlaydateRemote.fromJson(r)),
        ...rsvpPlaydates.map((r) => PlaydateRemote.fromJson(r)),
      ];

      all.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      _log.info('Fetched ${all.length} of my playdates');
      return all;
    } catch (e, st) {
      _log.severe('Failed to fetch my playdates', e, st);
      return [];
    }
  }

  // ── Cancel ──────────────────────────────────────────────────────────────

  /// Cancel a playdate (only the organizer may cancel).
  Future<bool> cancelPlaydate(String playdateId) async {
    try {
      await _client
          .from('playdates')
          .update({'status': 'cancelled'})
          .eq('id', playdateId)
          .eq('organizer_id', _userId);
      _log.info('Cancelled playdate $playdateId');
      return true;
    } catch (e, st) {
      _log.severe('Failed to cancel playdate', e, st);
      return false;
    }
  }

  // ── Haversine ──────────────────────────────────────────────────────────

  /// Haversine distance in miles between two lat/lon points.
  static double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMiles = 3958.8;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMiles * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}

// ─── Provider ────────────────────────────────────────────────────────────────

/// Returns [PlaydateService] when authenticated, or null when offline/unauthenticated.
final playdateServiceProvider = Provider<PlaydateService?>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  return PlaydateService(Supabase.instance.client);
});
