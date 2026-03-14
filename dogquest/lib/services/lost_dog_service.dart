import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import '../models/lost_dog_report.dart';
import '../models/my_dog_profile.dart';
import 'dog_embedding_service.dart';
import 'location_service.dart';

final _log = Logger('LostDogService');

/// Manages the Lost Dog Recognition Network — reporting lost dogs,
/// scanning strays, and matching via visual embeddings.
class LostDogService {
  final Box _box;
  final DogEmbeddingService _embeddingSvc;
  final LocationService _locationSvc;

  static const _reportsKey = 'lost_dog_reports';
  static const _scansKey = 'stray_scan_count';

  /// Minimum cosine similarity to consider a match.
  static const _matchThreshold = 0.50;

  LostDogService(this._box, this._embeddingSvc, this._locationSvc);

  // ─── Reports ────────────────────────────────────────────────────────────

  /// All lost dog reports (any status).
  List<LostDogReport> get allReports {
    final raw = _box.get(_reportsKey) as String?;
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => LostDogReport.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Only active (missing) reports.
  List<LostDogReport> get activeReports =>
      allReports.where((r) => r.status == LostDogStatus.active).toList();

  /// Number of dogs currently missing.
  int get activeLostCount => activeReports.length;

  /// Total stray scans performed.
  int get totalScans => _box.get(_scansKey, defaultValue: 0) as int;

  /// Report a dog as lost. Extracts embedding from the dog's photo.
  Future<LostDogReport> reportLost(
    MyDogProfile dog, {
    String? notes,
    String? ownerContact,
  }) async {
    List<double> embedding = [];
    if (dog.photoPath != null) {
      final file = File(dog.photoPath!);
      if (await file.exists()) {
        embedding = await _embeddingSvc.extractEmbedding(file);
      }
    }

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

  // ─── Scanning & Matching ───────────────────────────────────────────────

  /// Scan a photo of a found/stray dog and match against active lost reports.
  ///
  /// Returns matches sorted by similarity (highest first).
  Future<StrayScanResult> scanStray(File photo) async {
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

        matches.add(LostDogMatch(
          reportId: report.id,
          dogName: report.dogName,
          breed: report.breed,
          photoPath: report.photoPath,
          similarity: similarity,
          distanceKm: distanceKm,
        ));
      }
    }

    // Sort by similarity descending
    matches.sort((a, b) => b.similarity.compareTo(a.similarity));

    _log.info('Stray scan: ${matches.length} match(es) found');
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

  String _generateId() {
    final rng = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rand = rng.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return '$timestamp-$rand';
  }

  /// Haversine formula for distance between two GPS coordinates (in km).
  static double _haversineKm(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);
}

final lostDogServiceProvider = Provider<LostDogService>((ref) {
  throw UnimplementedError('lostDogServiceProvider must be overridden after Hive init');
});
