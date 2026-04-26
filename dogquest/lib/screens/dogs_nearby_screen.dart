import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/sighting_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/location_service.dart';

/// "Dogs Nearby" — when authenticated, calls the get_dogs_nearby RPC.
/// Falls back to local sighting data when offline.
class DogsNearbyScreen extends ConsumerStatefulWidget {
  const DogsNearbyScreen({super.key});

  @override
  ConsumerState<DogsNearbyScreen> createState() => _DogsNearbyScreenState();
}

class _DogsNearbyScreenState extends ConsumerState<DogsNearbyScreen> {
  double _radiusMiles = 5.0;
  double _refLat = 0;
  double _refLon = 0;
  bool _hasLocation = false;
  bool _isLoading = true;
  List<_NearbyDogData> _remoteDogs = [];

  bool get _isOnline => Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final locSvc = ref.read(locationServiceProvider);
      final pos = await locSvc.getLocation();
      if (pos != null && mounted) {
        setState(() {
          _refLat = pos.latitude;
          _refLon = pos.longitude;
          _hasLocation = true;
        });
        if (_isOnline) {
          await _fetchRemoteDogs();
        } else {
          setState(() => _isLoading = false);
        }
        return;
      }
    } catch (_) {}

    // Fallback: use most recent sighting with GPS
    final sightingSvc = ref.read(sightingServiceProvider);
    final recentWithGps = sightingSvc.all
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();
    if (recentWithGps.isNotEmpty) {
      setState(() {
        _refLat = recentWithGps.first.latitude!;
        _refLon = recentWithGps.first.longitude!;
        _hasLocation = true;
      });
    }
    if (_isOnline && _hasLocation) {
      await _fetchRemoteDogs();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRemoteDogs() async {
    setState(() => _isLoading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client.rpc(
        'get_dogs_nearby',
        params: {
          'p_user_id': uid,
          'p_lat': _refLat,
          'p_lon': _refLon,
          'p_radius_miles': _radiusMiles,
          'p_limit': 50,
        },
      );

      final list = response as List<dynamic>;
      if (mounted) {
        setState(() {
          _remoteDogs = list.map((e) {
            final json = e as Map<String, dynamic>;
            return _NearbyDogData(
              dogId: json['dog_id'] as String,
              dogName: json['dog_name'] as String,
              breed: json['breed'] as String,
              photoUrl: json['photo_url'] as String?,
              ownerUsername: json['owner_username'] as String,
              ownerDisplayName: json['owner_display_name'] as String?,
              distanceMiles: (json['distance_miles'] as num).toDouble(),
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline && _hasLocation) {
      return _buildRemoteView();
    }
    return _buildLocalView();
  }

  // ─── Remote (Supabase) view ──────────────────────────────

  Widget _buildRemoteView() {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        title: const Text('Dogs Nearby'),
        backgroundColor: bgCard,
        actions: [_radiusMenu()],
      ),
      body: Column(
        children: [
          _statsBanner(_remoteDogs.length),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: accent))
                : RefreshIndicator(
                    onRefresh: _fetchRemoteDogs,
                    color: accent,
                    child: _remoteDogs.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: _remoteDogs.length,
                            itemBuilder: (context, index) {
                              final dog = _remoteDogs[index];
                              return _RemoteNearbyCard(dog: dog)
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(milliseconds: index * 40),
                                  )
                                  .slideX(begin: 0.05, end: 0);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Local (offline) view ────────────────────────────────

  Widget _buildLocalView() {
    final sightingSvc = ref.watch(sightingServiceProvider);
    final dogSvc = ref.watch(dogServiceProvider);
    final radiusKm = _radiusMiles * 1.60934;

    final allSightings = sightingSvc.all
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    final breedClosest = <String, (Sighting, double)>{};
    for (final s in allSightings) {
      final dist = _hasLocation
          ? _distanceKm(_refLat, _refLon, s.latitude!, s.longitude!)
          : 0.0;
      if (dist <= radiusKm || !_hasLocation) {
        final existing = breedClosest[s.dogName];
        if (existing == null || dist < existing.$2) {
          breedClosest[s.dogName] = (s, dist);
        }
      }
    }

    final sorted = breedClosest.entries.toList()
      ..sort((a, b) => a.value.$2.compareTo(b.value.$2));

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        title: const Text('Dogs Nearby'),
        backgroundColor: bgCard,
        actions: [_radiusMenu()],
      ),
      body: Column(
        children: [
          _statsBanner(sorted.length),
          Expanded(
            child: sorted.isEmpty
                ? _emptyState()
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

                      return _LocalNearbyCard(
                        dogName: dogName,
                        breed: dog?.name ?? dogName,
                        distanceKm: distance,
                        hasLocation: _hasLocation,
                        sightingCount: sightingCount,
                        lastSeen: sighting.timestamp,
                        rarity: dog?.rarity ?? Rarity.common,
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: index * 40))
                          .slideX(begin: 0.05, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Shared widgets ──────────────────────────────────────

  Widget _radiusMenu() {
    return PopupMenuButton<double>(
      icon: const Icon(Icons.tune, color: textPrimary),
      color: bgCard,
      onSelected: (r) {
        setState(() => _radiusMiles = r);
        if (_isOnline && _hasLocation) _fetchRemoteDogs();
      },
      itemBuilder: (_) => [1.0, 2.0, 5.0, 10.0, 25.0]
          .map(
            (r) => PopupMenuItem(
              value: r,
              child: Text(
                '${r.toStringAsFixed(0)} mi radius',
                style: TextStyle(
                  color: r == _radiusMiles ? accent : textPrimary,
                  fontWeight:
                      r == _radiusMiles ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _statsBanner(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bgCard,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(icon: Icons.pets, label: '$count', subtitle: 'dogs nearby'),
          _StatChip(
            icon: Icons.radar,
            label: '${_radiusMiles.toStringAsFixed(0)} mi',
            subtitle: 'radius',
          ),
          _StatChip(
            icon: Icons.location_on,
            label: _hasLocation ? 'Active' : 'No GPS',
            subtitle: 'location',
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.explore_off,
                size: 64,
                color: textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No dogs spotted nearby yet',
                style: TextStyle(color: textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _hasLocation
                    ? 'Try expanding your search radius!'
                    : 'Enable location to find nearby dogs.',
                style: TextStyle(
                  color: textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;
}

// ─── Data class for remote dogs ────────────────────────────

class _NearbyDogData {
  final String dogId;
  final String dogName;
  final String breed;
  final String? photoUrl;
  final String ownerUsername;
  final String? ownerDisplayName;
  final double distanceMiles;

  const _NearbyDogData({
    required this.dogId,
    required this.dogName,
    required this.breed,
    this.photoUrl,
    required this.ownerUsername,
    this.ownerDisplayName,
    required this.distanceMiles,
  });
}

// ─── Remote dog card ───────────────────────────────────────

class _RemoteNearbyCard extends StatelessWidget {
  final _NearbyDogData dog;
  const _RemoteNearbyCard({required this.dog});

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
            // Dog photo or paw icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: dog.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: dog.photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.pets, color: accent, size: 24),
                    )
                  : const Icon(Icons.pets, color: accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dog.dogName,
                    style: const TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dog.breed,
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.near_me, size: 12, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        dog.distanceMiles < 0.5
                            ? '${(dog.distanceMiles * 5280).toStringAsFixed(0)} ft away'
                            : '${dog.distanceMiles.toStringAsFixed(1)} mi away',
                        style: const TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.person, size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        dog.ownerDisplayName ?? dog.ownerUsername,
                        style:
                            const TextStyle(color: textSecondary, fontSize: 12),
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

// ─── Local dog card (offline fallback) ─────────────────────

class _LocalNearbyCard extends StatelessWidget {
  final String dogName;
  final String breed;
  final double distanceKm;
  final bool hasLocation;
  final int sightingCount;
  final DateTime lastSeen;
  final Rarity rarity;

  const _LocalNearbyCard({
    required this.dogName,
    required this.breed,
    required this.distanceKm,
    required this.hasLocation,
    required this.sightingCount,
    required this.lastSeen,
    required this.rarity,
  });

  Color get _rarityColor {
    switch (rarity) {
      case Rarity.uncommon:
        return Colors.green;
      case Rarity.rare:
        return Colors.blue;
      case Rarity.legendary:
        return Colors.purple;
      default:
        return textSecondary;
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          breed,
                          style: const TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (rarity != Rarity.common)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _rarityColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rarity.name.toUpperCase(),
                            style: TextStyle(
                              color: _rarityColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (hasLocation) ...[
                        const Icon(Icons.near_me, size: 12, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          distanceKm < 1
                              ? '${(distanceKm * 1000).toStringAsFixed(0)}m away'
                              : '${distanceKm.toStringAsFixed(1)}km away',
                          style: const TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Icon(Icons.visibility,
                          size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '$sightingCount sighting${sightingCount != 1 ? "s" : ""}',
                        style:
                            const TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time,
                          size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _timeAgo(lastSeen),
                        style:
                            const TextStyle(color: textSecondary, fontSize: 12),
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

// ─── Shared stat chip ──────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(subtitle,
            style: const TextStyle(color: textSecondary, fontSize: 11)),
      ],
    );
  }
}
