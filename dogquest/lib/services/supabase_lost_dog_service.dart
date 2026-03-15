import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final _log = Logger('SupabaseLostDogService');
const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// A lost dog report fetched from Supabase.
class LostDogReportRemote {
  final String id;
  final String userId;
  final String? dogProfileId;
  final String dogName;
  final String breed;
  final String? photoUrl;
  final String description;
  final double lastSeenLat;
  final double lastSeenLon;
  final DateTime lastSeenAt;
  final String contactInfo;
  final String status; // 'active' | 'found' | 'cancelled'
  final double alertRadiusMiles;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  /// Only populated by the `get_active_lost_dogs` RPC.
  final double? distanceMiles;
  final int? sightingCount;

  const LostDogReportRemote({
    required this.id,
    required this.userId,
    this.dogProfileId,
    required this.dogName,
    required this.breed,
    this.photoUrl,
    required this.description,
    required this.lastSeenLat,
    required this.lastSeenLon,
    required this.lastSeenAt,
    required this.contactInfo,
    required this.status,
    this.alertRadiusMiles = 10.0,
    required this.createdAt,
    this.resolvedAt,
    this.distanceMiles,
    this.sightingCount,
  });

  factory LostDogReportRemote.fromJson(Map<String, dynamic> json) {
    return LostDogReportRemote(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      dogProfileId: json['dog_profile_id'] as String?,
      dogName: json['dog_name'] as String,
      breed: json['breed'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      description: json['description'] as String? ?? '',
      lastSeenLat: (json['last_seen_lat'] as num).toDouble(),
      lastSeenLon: (json['last_seen_lon'] as num).toDouble(),
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
      contactInfo: json['contact_info'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      alertRadiusMiles:
          (json['alert_radius_miles'] as num?)?.toDouble() ?? 10.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      distanceMiles: (json['distance_miles'] as num?)?.toDouble(),
      sightingCount: json['sighting_count'] as int?,
    );
  }

  bool get isActive => status == 'active';
}

/// A sighting of a lost dog reported by another user.
class LostDogSightingRemote {
  final String id;
  final String reportId;
  final String reporterId;
  final double latitude;
  final double longitude;
  final String? note;
  final DateTime createdAt;

  const LostDogSightingRemote({
    required this.id,
    required this.reportId,
    required this.reporterId,
    required this.latitude,
    required this.longitude,
    this.note,
    required this.createdAt,
  });

  factory LostDogSightingRemote.fromJson(Map<String, dynamic> json) {
    return LostDogSightingRemote(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      reporterId: json['reporter_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Supabase-backed service for lost dog reporting, sightings, and real-time
/// updates. Complements the local [LostDogService] (Hive-based).
class SupabaseLostDogService {
  final SupabaseClient _client;

  SupabaseLostDogService(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ─── Photo upload ───────────────────────────────────────────────────────

  /// Uploads a photo to the `lost-dog-photos` storage bucket.
  /// Returns the public URL on success, or `null` on failure.
  Future<String?> _uploadPhoto(File photoFile) async {
    final uid = _userId;
    if (uid == null) return null;

    try {
      final ext = photoFile.path.split('.').last.toLowerCase();
      final filename = 'lost_dogs/$uid/${_uuid.v4()}.$ext';

      await _client.storage.from('lost-dog-photos').upload(
            filename,
            photoFile,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      final publicUrl =
          _client.storage.from('lost-dog-photos').getPublicUrl(filename);
      _log.info('Uploaded lost dog photo: $filename');
      return publicUrl;
    } catch (e) {
      _log.warning('Failed to upload lost dog photo: $e');
      return null;
    }
  }

  // ─── Report lost ───────────────────────────────────────────────────────

  /// Create a new lost dog report. Optionally uploads a photo first.
  /// Returns the inserted report, or `null` on failure.
  Future<LostDogReportRemote?> reportLost({
    required String dogName,
    required String breed,
    File? photoFile,
    required String description,
    required double lastSeenLat,
    required double lastSeenLon,
    required String contactInfo,
    String? dogProfileId,
    double alertRadiusMiles = 10.0,
  }) async {
    final uid = _userId;
    if (uid == null) {
      _log.warning('Cannot report lost dog: not authenticated');
      return null;
    }

    try {
      String? photoUrl;
      if (photoFile != null) {
        photoUrl = await _uploadPhoto(photoFile);
      }

      final response = await _client
          .from('lost_dog_reports')
          .insert({
            'user_id': uid,
            'dog_name': dogName,
            'breed': breed,
            if (photoUrl != null) 'photo_url': photoUrl,
            'description': description,
            'last_seen_lat': lastSeenLat,
            'last_seen_lon': lastSeenLon,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
            'contact_info': contactInfo,
            'status': 'active',
            'alert_radius_miles': alertRadiusMiles,
            if (dogProfileId != null) 'dog_profile_id': dogProfileId,
          })
          .select()
          .single();

      _log.info('Created lost dog report for "$dogName"');
      return LostDogReportRemote.fromJson(response);
    } catch (e) {
      _log.severe('Failed to create lost dog report: $e');
      return null;
    }
  }

  // ─── Nearby active reports ─────────────────────────────────────────────

  /// Fetch active lost dog reports near a location using the
  /// `get_active_lost_dogs` RPC (server-side distance calculation).
  Future<List<LostDogReportRemote>> getActiveNearby(
    double lat,
    double lon, {
    double radiusMiles = 10.0,
  }) async {
    try {
      final response = await _client.rpc('get_active_lost_dogs', params: {
        'p_lat': lat,
        'p_lon': lon,
        'p_radius_miles': radiusMiles,
      });

      final list = response as List<dynamic>;
      return list
          .map((e) =>
              LostDogReportRemote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to fetch nearby lost dogs: $e');
      return [];
    }
  }

  // ─── Sightings ─────────────────────────────────────────────────────────

  /// Report a sighting of a lost dog.
  Future<LostDogSightingRemote?> reportSighting(
    String reportId,
    double lat,
    double lon, {
    String? note,
  }) async {
    final uid = _userId;
    if (uid == null) {
      _log.warning('Cannot report sighting: not authenticated');
      return null;
    }

    try {
      final response = await _client
          .from('lost_dog_sightings')
          .insert({
            'report_id': reportId,
            'reporter_id': uid,
            'latitude': lat,
            'longitude': lon,
            if (note != null) 'note': note,
          })
          .select()
          .single();

      _log.info('Reported sighting for report $reportId');
      return LostDogSightingRemote.fromJson(response);
    } catch (e) {
      _log.severe('Failed to report sighting: $e');
      return null;
    }
  }

  /// Fetch all sightings for a given report, ordered by most recent first.
  Future<List<LostDogSightingRemote>> getSightings(String reportId) async {
    try {
      final response = await _client
          .from('lost_dog_sightings')
          .select()
          .eq('report_id', reportId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((e) =>
              LostDogSightingRemote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to fetch sightings for report $reportId: $e');
      return [];
    }
  }

  /// Real-time stream of sightings for a report (for live map updates).
  /// Emits a new list snapshot whenever a row in `lost_dog_sightings` with
  /// the matching `report_id` is inserted, updated, or deleted.
  Stream<List<LostDogSightingRemote>> watchSightings(String reportId) {
    return _client
        .from('lost_dog_sightings')
        .stream(primaryKey: ['id'])
        .eq('report_id', reportId)
        .order('created_at')
        .map((rows) => rows
            .map((e) => LostDogSightingRemote.fromJson(e))
            .toList());
  }

  // ─── Report lifecycle ──────────────────────────────────────────────────

  /// Mark a lost dog report as found.
  Future<bool> markFound(String reportId) async {
    try {
      await _client.from('lost_dog_reports').update({
        'status': 'found',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', reportId);

      _log.info('Marked report $reportId as found');
      return true;
    } catch (e) {
      _log.severe('Failed to mark report as found: $e');
      return false;
    }
  }

  /// Cancel a lost dog report.
  Future<bool> cancelReport(String reportId) async {
    try {
      await _client.from('lost_dog_reports').update({
        'status': 'cancelled',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', reportId);

      _log.info('Cancelled report $reportId');
      return true;
    } catch (e) {
      _log.severe('Failed to cancel report: $e');
      return false;
    }
  }

  // ─── My reports ────────────────────────────────────────────────────────

  /// Fetch the current user's own lost dog reports, newest first.
  Future<List<LostDogReportRemote>> getMyReports() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final response = await _client
          .from('lost_dog_reports')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((e) =>
              LostDogReportRemote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to fetch my reports: $e');
      return [];
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provides [SupabaseLostDogService] when the user is authenticated,
/// or `null` when offline / unauthenticated.
final supabaseLostDogServiceProvider =
    Provider<SupabaseLostDogService?>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  return SupabaseLostDogService(Supabase.instance.client);
});
