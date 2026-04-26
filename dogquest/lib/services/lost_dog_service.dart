import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:dogquest/models/lost_dog_report.dart';
import 'package:dogquest/models/my_dog_profile.dart';
import 'package:dogquest/services/dog_embedding_service.dart';
import 'package:dogquest/services/location_service.dart';
import 'package:dogquest/services/supabase_lost_dog_service.dart';

final _log = Logger('LostDogService');

/// Manages the Lost Dog Recognition Network — reporting lost dogs,
/// scanning strays, and matching via visual embeddings.
class LostDogService {
  final Box _box;
  final DogEmbeddingService _embeddingSvc;
  final LocationService _locationSvc;

  static const _reportsKey = 'lost_dog_reports';
  static const _scansKey = 'stray_scan_count';

  /// Minimum cosine similarity to surface a possible breed match.
  /// Set deliberately high (0.75) to reduce false positives on a missing-pet feature.
  static const _matchThreshold = 0.75;

  LostDogService(this._box, this._embeddingSvc, this._locationSvc);

  // ─── Reports ────────────────────────────────────────────────────────────

  /// All lost dog reports (any status).
  List<LostDogReport> get allReports {
    final raw = _box.get(_reportsKey) as String?;
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => LostDogReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Only active (missing) reports.
  List<LostDogReport> get activeReports =>
      allReports.where((r) => r.status == LostDogStatus.active).toList();

  /// Number of dogs currently missing.
  int get activeLostCount => activeReports.length;

  /// Total stray scans performed.
  int get totalScans => _box.get(_scansKey, defaultValue: 0) as int;

  /// Report a dog as lost. Extracts embeddings from up to [additionalPhotos] + 1
  /// (the dog's primary photo). Averages all embeddings before storing to reduce
  /// variance in the visual fingerprint.
  Future<LostDogReport> reportLost(
    MyDogProfile dog, {
    String? notes,
    String? ownerContact,
    List<File> additionalPhotos = const [],
    DateTime? gdprConsentAt,
  }) async {
    final allEmbeddings = <List<double>>[];

    // Primary photo from dog profile
    if (dog.photoPath != null) {
      final file = File(dog.photoPath!);
      if (await file.exists()) {
        final emb = await _embeddingSvc.extractEmbedding(file);
        if (emb.isNotEmpty) allEmbeddings.add(emb);
      }
    }

    // Additional photos (up to 2 more, capped at first 2 even if more passed)
    for (final extraFile in additionalPhotos.take(2)) {
      if (await extraFile.exists()) {
        final emb = await _embeddingSvc.extractEmbedding(extraFile);
        if (emb.isNotEmpty) allEmbeddings.add(emb);
      }
    }

    final embedding = DogEmbeddingService.averageEmbeddings(allEmbeddings);
    _log.info(
      'Averaged ${allEmbeddings.length} embedding(s) for ${dog.name}',
    );

    final report = LostDogReport(
      id: _generateId(),
      dogName: dog.name,
      breed: dog.breed,
      photoPath: dog.photoPath,
      embedding: embedding,
      lastSeenLat: _locationSvc.latitude,
      lastSeenLon: _locationSvc.longitude,
      lastSeenLocation: null,
      lostDate: DateTime.now(),
      createdAt: DateTime.now(),
      ownerContact: ownerContact,
      notes: notes,
      gdprConsentAt: gdprConsentAt,
      syncStatus: SyncStatus.pending,
    );

    final reports = allReports;
    reports.add(report);
    _saveReports(reports);

    _log.info('Dog reported lost: ${dog.name} (${report.id})');
    return report;
  }

  /// Mark a lost dog as found/reunited.
  void markFound(String reportId) {
    final reports = allReports;
    final idx = reports.indexWhere((r) => r.id == reportId);
    if (idx >= 0) {
      reports[idx] = reports[idx].copyWith(status: LostDogStatus.found);
      _saveReports(reports);
      _log.info('Dog marked found: ${reports[idx].dogName}');
    }
  }

  /// Cancel a lost dog report.
  void cancelReport(String reportId) {
    final reports = allReports;
    final idx = reports.indexWhere((r) => r.id == reportId);
    if (idx >= 0) {
      reports[idx] = reports[idx].copyWith(status: LostDogStatus.cancelled);
      _saveReports(reports);
      _log.info('Report cancelled: ${reports[idx].dogName}');
    }
  }

  /// Update the sync status of a lost dog report.
  void updateSyncStatus(String reportId, SyncStatus status) {
    final reports = allReports;
    final idx = reports.indexWhere((r) => r.id == reportId);
    if (idx >= 0) {
      reports[idx] = reports[idx].copyWith(syncStatus: status);
      _saveReports(reports);
    }
  }

  // ─── Scanning & Matching ───────────────────────────────────────────────

  /// Scan a photo of a found/stray dog and match against active lost reports.
  ///
  /// Matches against:
  /// 1. Local Hive reports (always).
  /// 2. Remote Supabase reports within 25 km (when [supabaseSvc] is provided
  ///    and the device has a known location). Remote reports without an
  ///    embedding are silently skipped.
  ///
  /// Returns matches sorted by similarity (highest first), deduplicated by ID.
  Future<StrayScanResult> scanStray(
    File photo, {
    SupabaseLostDogService? supabaseSvc,
  }) async {
    final embedding = await _embeddingSvc.extractEmbedding(photo);
    _box.put(_scansKey, totalScans + 1);

    if (embedding.isEmpty) {
      _log.warning('Could not extract embedding from scan photo');
      return StrayScanResult(
        scanId: _generateId(),
        photoPath: photo.path,
        scannedAt: DateTime.now(),
      );
    }

    final matches = <LostDogMatch>[];
    for (final report in activeReports) {
      if (report.embedding.isEmpty) continue;

      final similarity = DogEmbeddingService.cosineSimilarity(
        embedding,
        report.embedding,
      );

      if (similarity >= _matchThreshold) {
        double? distanceKm;
        if (report.lastSeenLat != null &&
            report.lastSeenLon != null &&
            _locationSvc.hasLocation) {
          distanceKm = _haversineKm(
            _locationSvc.latitude!,
            _locationSvc.longitude!,
            report.lastSeenLat!,
            report.lastSeenLon!,
          );
        }

        matches.add(
          LostDogMatch(
            reportId: report.id,
            dogName: report.dogName,
            breed: report.breed,
            photoPath: report.photoPath,
            similarity: similarity,
            distanceKm: distanceKm,
          ),
        );
      }
    }

    // Sort by similarity descending
    matches.sort((a, b) => b.similarity.compareTo(a.similarity));

    // ── Remote network scan ──────────────────────────────────────────────
    if (supabaseSvc != null && _locationSvc.hasLocation) {
      final userLat = _locationSvc.latitude!;
      final userLon = _locationSvc.longitude!;

      final remoteReports = await supabaseSvc.getActiveNearby(
        userLat,
        userLon,
        radiusKm: 25.0,
      );

      final localIds = activeReports.map((r) => r.id).toSet();

      for (final remote in remoteReports) {
        // Skip if already matched locally or has no embedding.
        if (localIds.contains(remote.id)) continue;
        if (remote.embedding.isEmpty) continue;

        final similarity = DogEmbeddingService.cosineSimilarity(
          embedding,
          remote.embedding,
        );

        if (similarity >= _matchThreshold) {
          matches.add(
            LostDogMatch(
              reportId: remote.id,
              dogName: remote.dogName,
              breed: remote.breed.isEmpty ? null : remote.breed,
              photoPath: null, // remote reports use URLs, not local paths
              similarity: similarity,
              distanceKm: remote.distanceKm,
            ),
          );
        }
      }

      matches.sort((a, b) => b.similarity.compareTo(a.similarity));
      _log.info(
        'Stray scan (incl. network): ${matches.length} match(es) found',
      );
    } else {
      _log.info('Stray scan: ${matches.length} match(es) found');
    }

    return StrayScanResult(
      scanId: _generateId(),
      photoPath: photo.path,
      scannedAt: DateTime.now(),
      matches: matches,
    );
  }

  // ─── Demo Data ─────────────────────────────────────────────────────────

  /// Seed demo lost dog reports for investor demos.
  void seedDemoReports(List<LostDogReport> reports) {
    _saveReports(reports);
    _log.info('Seeded ${reports.length} demo lost dog reports');
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  void _saveReports(List<LostDogReport> reports) {
    _box.put(_reportsKey, jsonEncode(reports.map((r) => r.toJson()).toList()));
  }

  String _generateId() => const Uuid().v4();

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

final lostDogServiceProvider = Provider<LostDogService>((ref) {
  throw UnimplementedError(
    'lostDogServiceProvider must be overridden after Hive init',
  );
});
