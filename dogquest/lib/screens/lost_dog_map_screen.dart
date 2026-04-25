import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../constants.dart';
import '../models/lost_dog_report.dart';
import '../services/lost_dog_service.dart';
import '../services/supabase_lost_dog_service.dart';

/// Heat map and recovery metrics screen for the Lost Dog Recognition Network.
///
/// Shows a map of lost dog report locations (color-coded by status) and
/// a dashboard of recovery statistics — the data visualization that
/// demonstrates network value to investors.
class LostDogMapScreen extends ConsumerStatefulWidget {
  const LostDogMapScreen({super.key});

  @override
  ConsumerState<LostDogMapScreen> createState() => _LostDogMapScreenState();
}

class _LostDogMapScreenState extends ConsumerState<LostDogMapScreen> {
  final MapController _mapController = MapController();
  String? _selectedReportId;

  /// Whether the selected report is a remote (cloud) report.
  bool _selectedIsRemote = false;

  // NYC default center for demo data.
  static const _defaultCenter = LatLng(40.7580, -73.9855);
  static const _defaultZoom = 10.0;

  // ── Cloud state ──
  List<LostDogReportRemote> _remoteReports = [];
  List<LostDogSightingRemote> _liveSightings = [];
  StreamSubscription<List<LostDogSightingRemote>>? _sightingSub;
  bool _loadingRemote = false;

  @override
  void initState() {
    super.initState();
    _fetchRemoteReports();
  }

  @override
  void dispose() {
    _sightingSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchRemoteReports() async {
    final remoteSvc = ref.read(supabaseLostDogServiceProvider);
    if (remoteSvc == null) return;

    setState(() => _loadingRemote = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final reports = await remoteSvc.getActiveNearby(
        position.latitude,
        position.longitude,
        radiusMiles: 50.0,
      );
      setState(() {
        _remoteReports = reports;
        _loadingRemote = false;
      });
    } catch (_) {
      setState(() => _loadingRemote = false);
    }
  }

  void _subscribeToSightings(String reportId) {
    _sightingSub?.cancel();
    final remoteSvc = ref.read(supabaseLostDogServiceProvider);
    if (remoteSvc == null) return;

    _sightingSub = remoteSvc.watchSightings(reportId).listen((sightings) {
      setState(() => _liveSightings = sightings);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lostDogSvc = ref.read(lostDogServiceProvider);
    final reports = lostDogSvc.allReports;
    final totalScans = lostDogSvc.totalScans;

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        foregroundColor: textPrimary,
        title: const Text('Recovery Network'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Section 1: Map (top ~55%) ──────────────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.40,
            child: _buildMap(reports),
          ),

          // ── Section 2: Stats Dashboard (rest, scrollable) ─────────
          Expanded(
            child: _buildStatsDashboard(reports, totalScans),
          ),
        ],
      ),
    );
  }

  // ─── Map ──────────────────────────────────────────────────────────────

  Widget _buildMap(List<LostDogReport> reports) {
    // Compute center from reports with GPS, or use default.
    final geoReports = reports
        .where((r) => r.lastSeenLat != null && r.lastSeenLon != null)
        .toList();

    // Collect all lat/lons including remote reports for centering.
    final allLats = <double>[
      ...geoReports.map((r) => r.lastSeenLat!),
      ..._remoteReports.map((r) => r.lastSeenLat),
    ];
    final allLons = <double>[
      ...geoReports.map((r) => r.lastSeenLon!),
      ..._remoteReports.map((r) => r.lastSeenLon),
    ];

    LatLng center = _defaultCenter;
    double zoom = _defaultZoom;

    if (allLats.isNotEmpty) {
      allLats.sort();
      allLons.sort();
      center = LatLng(
        (allLats.first + allLats.last) / 2,
        (allLons.first + allLons.last) / 2,
      );
      // Compute zoom to fit all markers with padding
      final latSpan = (allLats.last - allLats.first).abs();
      final lonSpan = (allLons.last - allLons.first).abs();
      final span = latSpan > lonSpan ? latSpan : lonSpan;
      if (span > 0.5) {
        zoom = 9.0;
      } else if (span > 0.1) {
        zoom = 11.0;
      } else if (span > 0.01) {
        zoom = 13.0;
      } else {
        zoom = 14.0;
      }
    }

    return Stack(
      children: [
        // Dark background behind tiles (prevents light blue flash)
        Container(
          decoration: const BoxDecoration(
            color: bgDeep,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              minZoom: 3,
              maxZoom: 18,
              onTap: (_, __) => setState(() {
                _selectedReportId = null;
                _selectedIsRemote = false;
              }),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dogquest.app',
                fallbackUrl: 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              MarkerLayer(
                markers: [
                  ...geoReports.map(_buildMarker),
                  ..._remoteReports.map(_buildRemoteMarker),
                  ..._liveSightings.map(_buildSightingMarker),
                ],
              ),
            ],
          ),
        ),
        // Loading indicator for remote reports
        if (_loadingRemote)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bgCard.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.amber.shade300,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Loading cloud reports...',
                      style: TextStyle(
                          color: Colors.amber.shade300, fontSize: 11)),
                ],
              ),
            ),
          ),
        // Empty state when no reports have GPS
        if (geoReports.isEmpty && _remoteReports.isEmpty && !_loadingRemote)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined,
                    color: Colors.white.withValues(alpha: 0.3), size: 48),
                const SizedBox(height: 8),
                Text('No location data available',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text('Reports need GPS coordinates to appear on the map',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12)),
              ],
            ),
          ),
        // Marker popup overlay
        if (_selectedReportId != null && !_selectedIsRemote)
          _buildPopup(
            reports.firstWhere((r) => r.id == _selectedReportId),
          ),
        if (_selectedReportId != null && _selectedIsRemote)
          _buildRemotePopup(
            _remoteReports.firstWhere((r) => r.id == _selectedReportId),
          ),
        // Legend overlay
        if (geoReports.isNotEmpty || _remoteReports.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: _buildLegend(),
          ),
      ],
    );
  }

  Marker _buildMarker(LostDogReport report) {
    final color = _statusColor(report.status);

    return Marker(
      point: LatLng(report.lastSeenLat!, report.lastSeenLon!),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () {
          if (report.status == LostDogStatus.found)
            return; // reunited — no info access
          setState(() {
            _selectedReportId = report.id;
            _selectedIsRemote = false;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.pets, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildPopup(LostDogReport report) {
    final daysMissing = DateTime.now().difference(report.lostDate).inDays;
    final statusLabel = report.status == LostDogStatus.found
        ? 'Reunited'
        : report.status == LostDogStatus.cancelled
            ? 'Cancelled'
            : '$daysMissing day${daysMissing == 1 ? '' : 's'} missing';

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => _showReportDetail(context, report),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _statusColor(report.status).withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(report.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.pets,
                  color: _statusColor(report.status),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      report.dogName,
                      style: const TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.breed ?? 'Unknown breed',
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: _statusColor(report.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text('Tap for details',
                            style: TextStyle(
                                color: textSecondary.withValues(alpha: 0.6),
                                fontSize: 11)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            color: textSecondary.withValues(alpha: 0.6),
                            size: 14),
                      ],
                    ),
                  ],
                ),
              ),
              // Close button
              IconButton(
                icon: const Icon(Icons.close, color: textSecondary, size: 20),
                onPressed: () => setState(() => _selectedReportId = null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(Colors.redAccent, 'Missing'),
          const SizedBox(height: 4),
          _legendRow(Colors.green, 'Reunited'),
          const SizedBox(height: 4),
          _legendRow(Colors.grey, 'Cancelled'),
          if (_remoteReports.isNotEmpty) ...[
            const SizedBox(height: 4),
            _legendRow(Colors.blue, 'Cloud'),
          ],
          if (_liveSightings.isNotEmpty) ...[
            const SizedBox(height: 4),
            _legendRow(Colors.orange, 'Sighting'),
          ],
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 11)),
      ],
    );
  }

  // ─── Stats Dashboard ─────────────────────────────────────────────────

  Widget _buildStatsDashboard(List<LostDogReport> reports, int totalScans) {
    final activeCount =
        reports.where((r) => r.status == LostDogStatus.active).length;
    final foundCount =
        reports.where((r) => r.status == LostDogStatus.found).length;
    final cancelledCount =
        reports.where((r) => r.status == LostDogStatus.cancelled).length;
    final total = reports.length;

    final recoveryRate =
        total > 0 ? (foundCount / total * 100).toStringAsFixed(0) : '0';

    // Average recovery time: difference between lostDate and now for found reports.
    // In production this would use a "foundDate" field; for demo we estimate.
    double avgRecoveryDays = 0;
    if (foundCount > 0) {
      final foundReports =
          reports.where((r) => r.status == LostDogStatus.found).toList();
      final totalDays = foundReports.fold<int>(
        0,
        (sum, r) => sum + DateTime.now().difference(r.lostDate).inDays,
      );
      avgRecoveryDays = totalDays / foundCount;
    }

    // Sort reports by date for recent activity.
    final sortedReports = List<LostDogReport>.from(reports)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentReports = sortedReports.take(5).toList();

    return Container(
      decoration: const BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Recovery Network Stats',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),

            // 2x2 stat cards
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Total Reports',
                    '$total',
                    Icons.assignment,
                    accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    'Recovery Rate',
                    '$recoveryRate%',
                    Icons.verified,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Avg Recovery',
                    '${avgRecoveryDays.toStringAsFixed(1)}d',
                    Icons.timer,
                    const Color(0xFF42A5F5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    'Network Scans',
                    '$totalScans',
                    Icons.qr_code_scanner,
                    const Color(0xFFAB47BC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Recovery by Status bar chart
            const Text(
              'Recovery by Status',
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _statusBar('Missing', activeCount, total, Colors.redAccent),
            const SizedBox(height: 6),
            _statusBar('Reunited', foundCount, total, Colors.green),
            const SizedBox(height: 6),
            _statusBar('Cancelled', cancelledCount, total, Colors.grey),
            const SizedBox(height: 20),

            // Recent Activity
            const Text(
              'Recent Activity',
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ...recentReports.map(_recentActivityTile),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: bgDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBar(String label, int count, int total, Color color) {
    final fraction = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: bgDeep,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.04, 1.0), // min 4% for visibility
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recentActivityTile(LostDogReport report) {
    final daysAgo = DateTime.now().difference(report.createdAt).inDays;
    final timeLabel = daysAgo == 0
        ? 'Today'
        : daysAgo == 1
            ? 'Yesterday'
            : '$daysAgo days ago';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: report.status == LostDogStatus.found
              ? null
              : () => _showReportDetail(context, report),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bgDeep,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _statusColor(report.status).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor(report.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: report.status == LostDogStatus.found
                      ? Text(
                          'Reunited | $timeLabel',
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${report.dogName} — ${report.breed ?? 'Unknown'}',
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${report.status.label} | $timeLabel',
                              style: TextStyle(
                                color: _statusColor(report.status)
                                    .withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                ),
                if (report.status != LostDogStatus.found)
                  const Icon(Icons.chevron_right,
                      color: textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Remote / Sighting markers ─────────────────────────────────────────

  Marker _buildRemoteMarker(LostDogReportRemote report) {
    return Marker(
      point: LatLng(report.lastSeenLat, report.lastSeenLon),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedReportId = report.id;
            _selectedIsRemote = true;
          });
          _subscribeToSightings(report.id);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.pets, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Marker _buildSightingMarker(LostDogSightingRemote sighting) {
    return Marker(
      point: LatLng(sighting.latitude, sighting.longitude),
      width: 28,
      height: 28,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.4),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.visibility, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _buildRemotePopup(LostDogReportRemote report) {
    final daysMissing = DateTime.now().difference(report.lastSeenAt).inDays;
    final statusLabel =
        '$daysMissing day${daysMissing == 1 ? '' : 's'} missing';

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Status indicator
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        report.dogName,
                        style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.breed.isNotEmpty
                            ? report.breed
                            : 'Unknown breed',
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (report.distanceMiles != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${report.distanceMiles!.toStringAsFixed(1)} mi',
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (report.sightingCount != null &&
                              report.sightingCount! > 0) ...[
                            const Spacer(),
                            Icon(Icons.visibility,
                                color: Colors.orange.shade300, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              '${report.sightingCount} sighting${report.sightingCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: Colors.orange.shade300,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Close button
                IconButton(
                  icon: const Icon(Icons.close, color: textSecondary, size: 20),
                  onPressed: () => setState(() {
                    _selectedReportId = null;
                    _selectedIsRemote = false;
                    _sightingSub?.cancel();
                    _liveSightings = [];
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Report Sighting button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showReportSightingDialog(report),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text(
                  'Report Sighting',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportSightingDialog(LostDogReportRemote report) {
    final noteController = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: bgCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.visibility, color: Colors.orange.shade300, size: 22),
              const SizedBox(width: 8),
              const Text('Report Sighting',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You spotted ${report.dogName}? '
                'We\'ll use your current GPS location.',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Optional note (e.g. direction heading)...',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                  filled: true,
                  fillColor: bgDeep,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        final position = await Geolocator.getCurrentPosition(
                          locationSettings: const LocationSettings(
                            accuracy: LocationAccuracy.high,
                            timeLimit: Duration(seconds: 10),
                          ),
                        );
                        final remoteSvc =
                            ref.read(supabaseLostDogServiceProvider);
                        if (remoteSvc != null) {
                          await remoteSvc.reportSighting(
                            report.id,
                            position.latitude,
                            position.longitude,
                            note: noteController.text.isNotEmpty
                                ? noteController.text
                                : null,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: bgCard,
                              content: Text(
                                'Sighting reported for ${report.dogName}!',
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              backgroundColor: bgCard,
                              content: Text(
                                'Failed to submit sighting: $e',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
              ),
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  Color _statusColor(LostDogStatus status) {
    switch (status) {
      case LostDogStatus.active:
        return Colors.redAccent;
      case LostDogStatus.found:
        return Colors.green;
      case LostDogStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showReportDetail(BuildContext context, LostDogReport report) {
    HapticFeedback.lightImpact();
    final hasPhoto = report.photoPath != null &&
        report.photoPath!.isNotEmpty &&
        File(report.photoPath!).existsSync();
    final daysAgo = DateTime.now().difference(report.lostDate).inDays;
    final lostDogSvc = ref.read(lostDogServiceProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: hasPhoto
                      ? Image.file(File(report.photoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _photoPlaceholder())
                      : _photoPlaceholder(),
                ),
              ),
              const SizedBox(height: 16),

              // Name + status
              Row(
                children: [
                  Expanded(
                    child: Text(report.dogName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24)),
                  ),
                  _statusBadge(report.status),
                ],
              ),
              if (report.breed != null) ...[
                const SizedBox(height: 4),
                Text(report.breed!,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 15)),
              ],
              const SizedBox(height: 20),

              // Info rows
              _infoRow(Icons.schedule, Colors.red.shade300, 'Missing Since',
                  '${_formatDate(report.lostDate)} ($daysAgo day${daysAgo == 1 ? '' : 's'} ago)'),
              if (report.lastSeenLocation != null)
                _infoRow(Icons.location_on, Colors.amber, 'Last Seen',
                    report.lastSeenLocation!),
              if (report.lastSeenLat != null && report.lastSeenLon != null)
                _infoRow(Icons.map_outlined, Colors.blue.shade300, 'GPS',
                    '${report.lastSeenLat!.toStringAsFixed(4)}, ${report.lastSeenLon!.toStringAsFixed(4)}'),
              _infoRow(Icons.calendar_today, Colors.white38, 'Reported',
                  _formatDate(report.createdAt)),

              // Owner contact
              if (report.ownerContact != null &&
                  report.ownerContact!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone, color: Colors.amber.shade300, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Owner Contact',
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(report.ownerContact!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Notes
              if (report.notes != null && report.notes!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Description & Notes',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(report.notes!,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Share poster action
              _actionTile(
                icon: Icons.share,
                iconColor: Colors.amber,
                label: 'Share Lost Dog Poster',
                subtitle: 'Create a shareable poster to spread the word',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/lost-dog/share', extra: report);
                },
              ),
              const SizedBox(height: 8),

              // Mark found (only for active)
              if (report.status == LostDogStatus.active) ...[
                _actionTile(
                  icon: Icons.celebration,
                  iconColor: Colors.green,
                  label: 'Mark as Found',
                  subtitle: 'Great news! This dog has been reunited.',
                  onTap: () {
                    lostDogSvc.markFound(report.id);
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: Colors.amber.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets,
                color: Colors.amber.withValues(alpha: 0.4), size: 64),
            const SizedBox(height: 8),
            Text('No photo available',
                style: TextStyle(
                    color: Colors.amber.withValues(alpha: 0.4), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(LostDogStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, Color iconColor, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
