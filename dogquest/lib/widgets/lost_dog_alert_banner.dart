import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dogquest/models/lost_dog_report.dart';
import 'package:dogquest/services/lost_dog_service.dart';
import 'package:dogquest/services/location_service.dart';

/// Maximum distance (in km) to show the in-app banner.
///
/// This is intentionally wider than the push notification radius (2 km)
/// so the user sees a passive reminder even when slightly further away.
const _bannerRadiusKm = 5.0;

/// In-app banner displayed when the user is near an active lost dog report.
///
/// Shows the closest active report within [_bannerRadiusKm]. Designed to be
/// placed at the top of the identify screen or map tab. Tapping navigates
/// to the Lost Dog hub. The banner is dismissible.
///
/// Usage:
/// ```dart
/// Column(
///   children: [
///     const LostDogAlertBanner(),
///     // ... rest of screen content
///   ],
/// )
/// ```
class LostDogAlertBanner extends ConsumerStatefulWidget {
  const LostDogAlertBanner({super.key});

  @override
  ConsumerState<LostDogAlertBanner> createState() => _LostDogAlertBannerState();
}

class _LostDogAlertBannerState extends ConsumerState<LostDogAlertBanner> {
  bool _dismissed = false;
  _NearbyReport? _closest;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkProximity();
  }

  Future<void> _checkProximity() async {
    final locationSvc = ref.read(locationServiceProvider);
    final lostDogSvc = ref.read(lostDogServiceProvider);

    final position = await locationSvc.getLocation();
    if (!mounted) return;

    if (position == null) {
      setState(() => _loading = false);
      return;
    }

    final userLat = position.latitude;
    final userLon = position.longitude;

    _NearbyReport? closest;
    double closestDist = double.infinity;

    for (final report in lostDogSvc.activeReports) {
      if (report.lastSeenLat == null || report.lastSeenLon == null) continue;

      final dist = _haversineKm(
        userLat,
        userLon,
        report.lastSeenLat!,
        report.lastSeenLon!,
      );

      if (dist <= _bannerRadiusKm && dist < closestDist) {
        closestDist = dist;
        closest = _NearbyReport(report: report, distanceKm: dist);
      }
    }

    if (mounted) {
      setState(() {
        _closest = closest;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed || _closest == null) {
      return const SizedBox.shrink();
    }

    final nearby = _closest!;
    final report = nearby.report;
    final distStr = nearby.distanceKm < 1.0
        ? '${(nearby.distanceKm * 1000).round()} m'
        : '${nearby.distanceKm.toStringAsFixed(1)} km';
    final breedLabel = report.breed ?? 'dog';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Dismissible(
        key: ValueKey('lost_dog_banner_${report.id}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => setState(() => _dismissed = true),
        child: GestureDetector(
          onTap: () => context.push('/lost-dog'),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE65100).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Warning icon
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 10),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Lost Dog Nearby',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A $breedLabel named ${report.dogName} '
                        'was lost $distStr from here',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

/// Internal helper pairing a report with its computed distance.
class _NearbyReport {
  final LostDogReport report;
  final double distanceKm;

  const _NearbyReport({required this.report, required this.distanceKm});
}
