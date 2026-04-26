import 'dart:io';
import 'dart:math';

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
  final String? contactInfo;
  final String status; // 'active' | 'found' | 'cancelled'
  final double alertRadiusMiles;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? expiresAt;

  /// Only populated by the `get_active_lost_dogs` RPC.
  final double? distanceKm;
  final int? sightingCount;
  final List<double> embedding;
  final DateTime? gdprConsentAt;

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
    this.contactInfo,
    required this.status,
    this.alertRadiusMiles = 10.0,
    required this.createdAt,
    this.resolvedAt,
    this.expiresAt,
    this.distanceKm,
    this.sightingCount,
    this.embedding = const [],
    this.gdprConsentAt,
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
      contactInfo: json['contact_info'] as String?,
      status: json['status'] as String? ?? 'active',
      alertRadiusMiles:
          (json['alert_radius_miles'] as num?)?.toDouble() ?? 10.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      distanceKm: (json['distance_miles'] as num?) != null
          ? (json['distance_miles'] as num).toDouble() * 1.60934
          : null,
      sightingCount: json['sighting_count'] as int?,
      embedding: (json['embedding'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      gdprConsentAt: json['gdpr_consent_at'] != null
          ? DateTime.parse(json['gdpr_consent_at'] as String)
          : null,
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
  static final _rng = Random();

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

  /// Apply random jitter to a coordinate (latitude or longitude).
  /// Returns `coord + (_rng.nextDouble() * 2 - 1) * maxDeltaDeg`.
  double _fuzzCoord(double coord, double maxDeltaDeg) {
    return coord + (_rng.nextDouble() * 2 - 1) * maxDeltaDeg;
  }

  /// Extract storage object path from a Supabase public URL.
  /// Supabase format: `https://<project>.supabase.co/storage/v1/object/public/lost-dog-photos/<path>`
  /// Returns everything after `/lost-dog-photos/`, or `null` if not found.
  String? _storagePathFromUrl(String? url) {
    if (url == null) return null;
    const marker = '/lost-dog-photos/';
    final idx = url.indexOf(marker);
    if (idx < 0) return null;
    return url.substring(idx + marker.length);
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
    List<double> embedding = const [],
    DateTime? gdprConsentAt,
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
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(days: 90))
                .toIso8601String(),
            if (dogProfileId != null) 'dog_profile_id': dogProfileId,
            if (embedding.isNotEmpty) 'embedding': embedding,
            if (gdprConsentAt != null)
              'gdpr_consent_at': gdprConsentAt.toUtc().toIso8601String(),
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
  /// The RPC already filters by `status = 'active'`. We additionally filter
  /// expired reports client-side after the RPC returns (since we can't yet
  /// guarantee the RPC respects `expires_at`).
  ///
  /// GPS coordinates are fuzzy (±500m) for reporter privacy. The server
  /// calculates distance using precise coordinates; we display fuzzy ones.
  Future<List<LostDogReportRemote>> getActiveNearby(
    double lat,
    double lon, {
    double radiusKm = 16.0,
  }) async {
    try {
      final response = await _client.rpc('get_active_lost_dogs', params: {
        'p_lat': lat,
        'p_lon': lon,
        // RPC expects miles; convert from km at the boundary.
        'p_radius_miles': radiusKm / 1.60934,
      });

      final list = response as List<dynamic>;
      final now = DateTime.now().toUtc();
      const maxDeltaDeg = 0.0045; // ≈500m at all latitudes
      return list
          .map((e) {
            final map = e as Map<String, dynamic>;
            final fuzzedMap = Map<String, dynamic>.from(map)
              ..['last_seen_lat'] = _fuzzCoord(
                  (map['last_seen_lat'] as num).toDouble(), maxDeltaDeg)
              ..['last_seen_lon'] = _fuzzCoord(
                  (map['last_seen_lon'] as num).toDouble(), maxDeltaDeg);
            return LostDogReportRemote.fromJson(fuzzedMap);
          })
          .where((r) => r.expiresAt == null || r.expiresAt!.isAfter(now))
          .toList();
    } catch (e) {
      _log.warning('Failed to fetch nearby lost dogs: $e');
      return [];
    }
  }

  /// Fetch contact info for a specific report — only called when the user
  /// explicitly taps "Request Contact". Never included in bulk nearby queries.
  ///
  /// Returns null if not authenticated, not found, or the report is not active.
  Future<String?> getContactInfo(String reportId) async {
    final uid = _userId;
    if (uid == null) return null;

    try {
      final response = await _client
          .from('lost_dog_reports')
          .select('contact_info')
          .eq('id', reportId)
          .eq('status', 'active')
          .single();

      return response['contact_info'] as String?;
    } catch (e) {
      _log.warning('Failed to fetch contact info for report $reportId: $e');
      return null;
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
          .map((e) => LostDogSightingRemote.fromJson(e as Map<String, dynamic>))
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
        .map((rows) =>
            rows.map((e) => LostDogSightingRemote.fromJson(e)).toList());
  }

  // ─── Report lifecycle ──────────────────────────────────────────────────

  /// Mark a lost dog report as found.
  /// Deletes the associated photo from storage before updating the status.
  Future<bool> markFound(String reportId) async {
    try {
      // Fetch the photo_url first.
      final reportRow = await _client
          .from('lost_dog_reports')
          .select('photo_url')
          .eq('id', reportId)
          .maybeSingle();

      if (reportRow != null) {
        final photoUrl = reportRow['photo_url'] as String?;
        final storagePath = _storagePathFromUrl(photoUrl);

        if (storagePath != null) {
          try {
            await _client.storage.from('lost-dog-photos').remove([storagePath]);
            _log.info('Deleted photo for report $reportId: $storagePath');
          } catch (e) {
            _log.warning(
              'Failed to delete photo for report $reportId: $e. '
              'Proceeding with status update.',
            );
          }
        }
      }

      // Update status.
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
  /// Deletes the associated photo from storage before updating the status.
  Future<bool> cancelReport(String reportId) async {
    try {
      // Fetch the photo_url first.
      final reportRow = await _client
          .from('lost_dog_reports')
          .select('photo_url')
          .eq('id', reportId)
          .maybeSingle();

      if (reportRow != null) {
        final photoUrl = reportRow['photo_url'] as String?;
        final storagePath = _storagePathFromUrl(photoUrl);

        if (storagePath != null) {
          try {
            await _client.storage.from('lost-dog-photos').remove([storagePath]);
            _log.info('Deleted photo for report $reportId: $storagePath');
          } catch (e) {
            _log.warning(
              'Failed to delete photo for report $reportId: $e. '
              'Proceeding with status update.',
            );
          }
        }
      }

      // Update status.
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
          .map((e) => LostDogReportRemote.fromJson(e as Map<String, dynamic>))
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
final supabaseLostDogServiceProvider = Provider<SupabaseLostDogService?>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  return SupabaseLostDogService(Supabase.instance.client);
});
