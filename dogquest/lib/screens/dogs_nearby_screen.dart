import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../services/sighting_service.dart';
import '../services/dog_service.dart';

/// "Dogs Nearby" — shows dogs spotted near a reference location,
/// sorted by proximity. Uses sighting GPS data.
class DogsNearbyScreen extends ConsumerStatefulWidget {
  const DogsNearbyScreen({super.key});

  @override
  ConsumerState<DogsNearbyScreen> createState() => _DogsNearbyScreenState();
}

class _DogsNearbyScreenState extends ConsumerState<DogsNearbyScreen> {
  double _radiusKm = 5.0; // search radius
  // Default to a central location; updated when we get real GPS
  double _refLat = 0;
  double _refLon = 0;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    // Try to get the most recent sighting with GPS as reference
    final sightingSvc = ref.read(sightingServiceProvider);
    final recentWithGps = sightingSvc.all.where((s) => s.latitude != null && s.longitude != null).toList();
    if (recentWithGps.isNotEmpty) {
      setState(() {
        _refLat = recentWithGps.first.latitude!;
        _refLon = recentWithGps.first.longitude!;
        _hasLocation = true;
      });
    }
  }

  /// Haversine distance in km.
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final sightingSvc = ref.watch(sightingServiceProvider);
    final dogSvc = ref.watch(dogServiceProvider);

    // Get all sightings with GPS, compute distances, group by breed
    final allSightings = sightingSvc.all
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    // Group by breed, find closest sighting per breed
    final breedClosest = <String, (Sighting, double)>{};
    for (final s in allSightings) {
      final dist = _hasLocation
          ? _distanceKm(_refLat, _refLon, s.latitude!, s.longitude!)
          : 0.0;
      if (dist <= _radiusKm || !_hasLocation) {
        final existing = breedClosest[s.dogName];
        if (existing == null || dist < existing.$2) {
          breedClosest[s.dogName] = (s, dist);
        }
      }
    }

    // Sort by distance
    final sorted = breedClosest.entries.toList()
      ..sort((a, b) => a.value.$2.compareTo(b.value.$2));

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        title: const Text('Dogs Nearby'),
        backgroundColor: bgCard,
        actions: [
          // Radius selector
          PopupMenuButton<double>(
            icon: const Icon(Icons.tune, color: textPrimary),
            color: bgCard,
            onSelected: (r) => setState(() => _radiusKm = r),
            itemBuilder: (_) => [1.0, 2.0, 5.0, 10.0, 25.0, 50.0].map((r) =>
              PopupMenuItem(
                value: r,
                child: Text(
                  '${r.toStringAsFixed(0)} km radius',
                  style: TextStyle(
                    color: r == _radiusKm ? accent : textPrimary,
                    fontWeight: r == _radiusKm ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: bgCard,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  icon: Icons.pets,
                  label: '${sorted.length}',
                  subtitle: 'breeds nearby',
                ),
                _StatChip(
                  icon: Icons.radar,
                  label: '${_radiusKm.toStringAsFixed(0)} km',
                  subtitle: 'radius',
                ),
                _StatChip(
                  icon: Icons.location_on,
                  label: _hasLocation ? 'Active' : 'No GPS',
                  subtitle: 'location',
                ),
              ],
            ),
          ),
          // Dog list
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.explore_off, size: 64, color: textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No dogs spotted nearby yet',
                          style: TextStyle(color: textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Go identify some dogs to populate the map!',
                          style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final entry = sorted[index];
                      final dogName = entry.key;
                      final sighting = entry.value.$1;
                      final distance = entry.value.$2;
                      final dog = dogSvc.lookupByCommonName(dogName);
                      final sightingCount = sightingSvc.sightingCount(dogName);

                      return _NearbyDogCard(
                        dogName: dogName,
                        breed: dog?.name ?? dogName,
                        distance: distance,
                        hasLocation: _hasLocation,
                        sightingCount: sightingCount,
                        lastSeen: sighting.timestamp,
                        rarity: dog?.rarity ?? Rarity.common,
                      ).animate()
                        .fadeIn(delay: Duration(milliseconds: index * 40))
                        .slideX(begin: 0.05, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _StatChip({required this.icon, required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 11)),
      ],
    );
  }
}

class _NearbyDogCard extends StatelessWidget {
  final String dogName;
  final String breed;
  final double distance;
  final bool hasLocation;
  final int sightingCount;
  final DateTime lastSeen;
  final Rarity rarity;

  const _NearbyDogCard({
    required this.dogName,
    required this.breed,
    required this.distance,
    required this.hasLocation,
    required this.sightingCount,
    required this.lastSeen,
    required this.rarity,
  });

  Color get _rarityColor {
    switch (rarity) {
      case Rarity.uncommon: return Colors.green;
      case Rarity.rare: return Colors.blue;
      case Rarity.legendary: return Colors.purple;
      default: return textSecondary;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: bgCard,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Paw icon with rarity color
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _rarityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.pets, color: _rarityColor, size: 24),
            ),
            const SizedBox(width: 12),
            // Dog info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          breed,
                          style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (rarity != Rarity.common)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _rarityColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rarity.name.toUpperCase(),
                            style: TextStyle(color: _rarityColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (hasLocation) ...[
                        Icon(Icons.near_me, size: 12, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          distance < 1
                              ? '${(distance * 1000).toStringAsFixed(0)}m away'
                              : '${distance.toStringAsFixed(1)}km away',
                          style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.visibility, size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '$sightingCount sighting${sightingCount != 1 ? "s" : ""}',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _timeAgo(lastSeen),
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
