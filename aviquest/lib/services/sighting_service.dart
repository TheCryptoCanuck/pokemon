import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('SightingService');

/// A single bird sighting record.
class Sighting {
  final String birdName;
  final DateTime timestamp;
  final double confidence;
  final String source; // 'ml', 'mock', 'audio'

  const Sighting({
    required this.birdName,
    required this.timestamp,
    this.confidence = 1.0,
    this.source = 'mock',
  });

  Map<String, dynamic> toMap() => {
    'bird': birdName,
    'ts': timestamp.toIso8601String(),
    'conf': confidence,
    'src': source,
  };

  factory Sighting.fromMap(Map<dynamic, dynamic> map) => Sighting(
    birdName: map['bird'] as String? ?? '',
    timestamp: DateTime.tryParse(map['ts'] as String? ?? '') ?? DateTime.now(),
    confidence: (map['conf'] as num?)?.toDouble() ?? 1.0,
    source: map['src'] as String? ?? 'mock',
  );
}

/// Tracks every bird sighting, enabling encounter history and stats.
class SightingService {
  static const _boxName = 'sightings_v1';
  late Box<Map> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
    _log.info('Sighting log loaded: ${_box.length} entries');
  }

  /// Record a new sighting.
  void log(Sighting sighting) {
    _box.add(sighting.toMap());
  }

  /// All sightings, newest first.
  List<Sighting> get all {
    return _box.values
        .map((m) => Sighting.fromMap(m))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Number of total sightings (not unique species).
  int get totalSightings => _box.length;

  /// Sightings for a specific bird.
  List<Sighting> forBird(String birdName) {
    return _box.values
        .map((m) => Sighting.fromMap(m))
        .where((s) => s.birdName == birdName)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// How many times a bird has been sighted.
  int sightingCount(String birdName) {
    return _box.values
        .where((m) => m['bird'] == birdName)
        .length;
  }

  /// Unique species sighted.
  int get uniqueSpecies {
    return _box.values.map((m) => m['bird'] as String?).toSet().length;
  }

  /// Recent sightings (last N).
  List<Sighting> recent({int limit = 20}) {
    final sightings = all;
    return sightings.take(limit).toList();
  }

  /// Sightings grouped by date (for the log view).
  Map<String, List<Sighting>> groupedByDate() {
    final sightings = all;
    final grouped = <String, List<Sighting>>{};
    for (final s in sightings) {
      final key = '${s.timestamp.year}-${s.timestamp.month.toString().padLeft(2, '0')}-${s.timestamp.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(s);
    }
    return grouped;
  }

  /// "Your best day" — date with most sightings.
  (String date, int count)? get bestDay {
    final grouped = groupedByDate();
    if (grouped.isEmpty) return null;
    final best = grouped.entries.reduce((a, b) => a.value.length >= b.value.length ? a : b);
    return (best.key, best.value.length);
  }

  /// Streak of encounter milestones for a bird.
  String? encounterMilestoneText(String birdName) {
    final count = sightingCount(birdName);
    if (count == 5) return 'Familiar Friend — 5th sighting!';
    if (count == 10) return 'Favorite Bird — 10th sighting!';
    if (count == 25) return 'Old Companion — 25th sighting!';
    if (count == 50) return 'Soulbird — 50th sighting!';
    return null;
  }
}

final sightingServiceProvider = Provider<SightingService>((ref) {
  throw UnimplementedError('sightingServiceProvider must be overridden');
});
