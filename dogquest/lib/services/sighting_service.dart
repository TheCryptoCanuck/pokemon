import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('SightingService');

/// A single dog sighting record.
class Sighting {
  final String dogName;
  final DateTime timestamp;
  final double confidence;
  final String source; // 'ml', 'mock', 'audio'
  final double? latitude;
  final double? longitude;
  final double? accuracy; // GPS accuracy in meters

  const Sighting({
    required this.dogName,
    required this.timestamp,
    this.confidence = 1.0,
    this.source = 'mock',
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  Map<String, dynamic> toMap() => {
        'dog': dogName,
        'ts': timestamp.toIso8601String(),
        'conf': confidence,
        'src': source,
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lon': longitude,
        if (accuracy != null) 'acc': accuracy,
      };

  factory Sighting.fromMap(Map<dynamic, dynamic> map) => Sighting(
        dogName: map['dog'] as String? ?? '',
        timestamp:
            DateTime.tryParse(map['ts'] as String? ?? '') ?? DateTime.now(),
        confidence: (map['conf'] as num?)?.toDouble() ?? 1.0,
        source: map['src'] as String? ?? 'mock',
        latitude: (map['lat'] as num?)?.toDouble(),
        longitude: (map['lon'] as num?)?.toDouble(),
        accuracy: (map['acc'] as num?)?.toDouble(),
      );
}

/// Tracks every dog sighting, enabling encounter history and stats.
///
/// Uses an in-memory cache to avoid repeated O(N) Hive deserialization.
/// The cache is lazily populated on first access and invalidated when a
/// new sighting is logged.
class SightingService {
  static const _boxName = 'dogquest_sightings_v1';
  late Box<Map> _box;

  // ── In-memory caches ──────────────────────────────────────────────
  List<Sighting>? _cachedAll;
  Map<String, int>? _cachedCounts;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
    _log.info('Sighting log loaded: ${_box.length} entries');
  }

  /// Invalidate all in-memory caches. Called after every mutation.
  void _invalidateCache() {
    _cachedAll = null;
    _cachedCounts = null;
  }

  /// Record a new sighting.
  void log(Sighting sighting) {
    _box.add(sighting.toMap());
    _invalidateCache();
  }

  /// All sightings, newest first. Lazily cached — only deserializes
  /// from the Hive box once per invalidation cycle.
  List<Sighting> get all {
    if (_cachedAll != null) return _cachedAll!;
    _cachedAll = _box.values.map((m) => Sighting.fromMap(m)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _cachedAll!;
  }

  /// Number of total sightings (not unique species).
  int get totalSightings => _box.length;

  /// Build (or return cached) per-breed sighting counts map.
  Map<String, int> get _counts {
    if (_cachedCounts != null) return _cachedCounts!;
    final counts = <String, int>{};
    for (final s in all) {
      counts[s.dogName] = (counts[s.dogName] ?? 0) + 1;
    }
    _cachedCounts = counts;
    return _cachedCounts!;
  }

  /// Sightings for a specific dog (derived from cached [all]).
  List<Sighting> forDog(String dogName) {
    return all.where((s) => s.dogName == dogName).toList();
  }

  /// How many times a dog has been sighted — O(1) lookup.
  int sightingCount(String dogName) {
    return _counts[dogName] ?? 0;
  }

  /// Unique species sighted (derived from cached counts).
  int get uniqueSpecies => _counts.length;

  /// Recent sightings (last N), derived from cached [all].
  List<Sighting> recent({int limit = 20}) {
    return all.take(limit).toList();
  }

  /// Sightings grouped by date (for the log view).
  Map<String, List<Sighting>> groupedByDate() {
    final sightings = all;
    final grouped = <String, List<Sighting>>{};
    for (final s in sightings) {
      final key =
          '${s.timestamp.year}-${s.timestamp.month.toString().padLeft(2, '0')}-${s.timestamp.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(s);
    }
    return grouped;
  }

  /// "Your best day" — date with most sightings.
  (String date, int count)? get bestDay {
    final grouped = groupedByDate();
    if (grouped.isEmpty) return null;
    final best = grouped.entries
        .reduce((a, b) => a.value.length >= b.value.length ? a : b);
    return (best.key, best.value.length);
  }

  /// Sightings grouped by breed name, only those with GPS coordinates.
  Map<String, List<Sighting>> sightingsByBreed() {
    final sightings = all;
    final grouped = <String, List<Sighting>>{};
    for (final s in sightings) {
      if (s.latitude != null && s.longitude != null) {
        grouped.putIfAbsent(s.dogName, () => []).add(s);
      }
    }
    return grouped;
  }

  /// Streak of encounter milestones for a dog.
  String? encounterMilestoneText(String dogName) {
    final count = sightingCount(dogName);
    if (count == 5) return 'Familiar Friend — 5th sighting!';
    if (count == 10) return 'Favorite Dog — 10th sighting!';
    if (count == 25) return 'Old Companion — 25th sighting!';
    if (count == 50) return 'Best Friend — 50th sighting!';
    return null;
  }
}

final sightingServiceProvider = Provider<SightingService>((ref) {
  throw UnimplementedError('sightingServiceProvider must be overridden');
});
