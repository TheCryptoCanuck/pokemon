import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/services/lost_dog_service.dart';
import 'package:dogquest/services/supabase_lost_dog_service.dart';

final _log = Logger('HelpFindTab');

class HelpFindTab extends ConsumerStatefulWidget {
  final LostDogService lostDogSvc;

  const HelpFindTab({super.key, required this.lostDogSvc});

  @override
  ConsumerState<HelpFindTab> createState() => _HelpFindTabState();
}

class _HelpFindTabState extends ConsumerState<HelpFindTab> {
  List<LostDogReportRemote> _nearbyReports = [];
  bool _loadingNearby = false;
  String? _nearbyError;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchNearby()); // sec-C1: explicit fire-and-forget
  }

  Future<void> _fetchNearby() async {
    final remoteSvc = ref.read(supabaseLostDogServiceProvider);
    if (remoteSvc == null) return;

    setState(() {
      _loadingNearby = true;
      _nearbyError = null;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return; // sec-C1
      final reports = await remoteSvc.getActiveNearby(
        position.latitude,
        position.longitude,
        radiusKm: 40.0,
      );
      if (!mounted) return; // sec-C1
      setState(() {
        _nearbyReports = reports;
        _loadingNearby = false;
      });
    } catch (e, st) {
      // sec-C3: surface geolocator/network exceptions instead of swallowing.
      _log.warning('Failed to fetch nearby lost-dog reports', e, st);
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'help_find_tab._fetchNearby',
          fatal: false,
        ),
      );
      if (!mounted) return;
      setState(() {
        _loadingNearby = false;
        _nearbyError = 'Could not fetch nearby reports';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not fetch nearby reports — check location & network.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingCount = widget.lostDogSvc.activeLostCount;
    final scanCount = widget.lostDogSvc.totalScans;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        children: [
          // Hero illustration area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.withValues(alpha: 0.10),
                  Colors.orange.withValues(alpha: 0.05),
                  bgCard,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                // Scan icon with pulse ring
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.25),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.1),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.center_focus_strong,
                      color: Colors.amber,
                      size: 52,
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.05, 1.05),
                      duration: 2000.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 28),
                const Text(
                  'Scan a Dog',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Found a dog? Take a photo and we\'ll check\nif it matches any lost dogs in our network.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Scan button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/lost-dog/scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: Colors.amber.withValues(alpha: 0.3),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 24),
                    label: const Text(
                      'Scan a Dog',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              _buildStatCard(
                icon: Icons.search,
                iconColor: Colors.redAccent,
                value: '$missingCount',
                label: 'Dogs Missing',
                bgColor: Colors.red,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                icon: Icons.qr_code_scanner,
                iconColor: Colors.amber,
                value: '$scanCount',
                label: 'Scans Performed',
                bgColor: Colors.amber,
              ),
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),

          const SizedBox(height: 24),

          // How it works
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How It Works',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStep(
                  number: '1',
                  title: 'Snap a Photo',
                  description: 'Take a clear photo of the dog you found',
                  icon: Icons.camera_alt,
                ),
                const SizedBox(height: 14),
                _buildStep(
                  number: '2',
                  title: 'AI Matching',
                  description:
                      'Our ML model compares visual features against all lost dog reports',
                  icon: Icons.auto_awesome,
                ),
                const SizedBox(height: 14),
                _buildStep(
                  number: '3',
                  title: 'Reunite',
                  description:
                      'If there\'s a match, contact the owner and bring them home',
                  icon: Icons.favorite,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05),

          const SizedBox(height: 24),

          // Network banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.08),
                  Colors.orange.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.public, color: Colors.amber.shade300, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global Recognition Network',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Every scan helps. Together, we can bring every lost dog home.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 500.ms),

          // ── Nearby Lost Dogs from Cloud ──
          if (_loadingNearby)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber.shade300,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Searching for lost dogs nearby...',
                      style:
                          TextStyle(color: Colors.amber.shade300, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (_nearbyError != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                _nearbyError!,
                style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          if (!_loadingNearby && _nearbyReports.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red.shade300, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${_nearbyReports.length} Lost Dog${_nearbyReports.length == 1 ? '' : 's'} Nearby',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 12),
            ..._nearbyReports.map((report) {
              final daysAgo =
                  DateTime.now().difference(report.lastSeenAt).inDays;
              final timeLabel = daysAgo == 0
                  ? 'Today'
                  : daysAgo == 1
                      ? '1 day ago'
                      : '$daysAgo days ago';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    // Photo or placeholder
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: report.photoUrl != null
                            ? Image.network(
                                report.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  child: const Center(
                                    child: Icon(
                                      Icons.pets,
                                      color: Colors.redAccent,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.red.withValues(alpha: 0.08),
                                child: const Center(
                                  child: Icon(
                                    Icons.pets,
                                    color: Colors.redAccent,
                                    size: 24,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.dogName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (report.breed.isNotEmpty)
                            Text(
                              report.breed,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Missing $timeLabel',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (report.distanceKm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${report.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.03);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bgColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
