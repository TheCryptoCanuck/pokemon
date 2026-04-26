import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../constants.dart';
import '../models/lost_dog_report.dart';
import '../services/lost_dog_map_controller.dart';
import '../services/lost_dog_service.dart';
import '../services/supabase_lost_dog_service.dart';
import '../widgets/lost_dog/lost_dog_detail_sheet.dart';
import '../widgets/lost_dog/lost_dog_stats_panel.dart';

class LostDogMapScreen extends ConsumerStatefulWidget {
  const LostDogMapScreen({super.key});

  @override
  ConsumerState<LostDogMapScreen> createState() => _LostDogMapScreenState();
}

class _LostDogMapScreenState extends ConsumerState<LostDogMapScreen> {
  final MapController _mapController = MapController();
  String? _selectedReportId;
  bool _selectedIsRemote = false;

  late LostDogMapController _controller;

  static const _defaultCenter = LatLng(40.7580, -73.9855);
  static const _defaultZoom = 10.0;

  @override
  void initState() {
    super.initState();
    _controller = LostDogMapController();
    _controller.addListener(_onControllerChanged);

    final remoteSvc = ref.read(supabaseLostDogServiceProvider);
    _controller.fetchRemoteReports(remoteSvc);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
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
          // ── Section 1: Map (top ~40%) ──
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.40,
            child: _LostDogMap(
              mapController: _mapController,
              reports: reports,
              remoteReports: _controller.remoteReports,
              liveSightings: _controller.liveSightings,
              loadingRemote: _controller.loadingRemote,
              selectedReportId: _selectedReportId,
              selectedIsRemote: _selectedIsRemote,
              onMarkerTap: (reportId, isRemote) {
                setState(() {
                  _selectedReportId = reportId;
                  _selectedIsRemote = isRemote;
                });
                if (isRemote) {
                  _controller.subscribeToSightings(
                    reportId,
                    ref.read(supabaseLostDogServiceProvider),
                  );
                }
              },
              onMapTap: () {
                setState(() {
                  _selectedReportId = null;
                  _selectedIsRemote = false;
                });
                _controller.clearSightings();
              },
              onReportSighting: _showReportSightingDialog,
              onReportTap: (report) {
                LostDogDetailSheet.show(context, report, lostDogSvc);
              },
            ),
          ),

          // ── Section 2: Stats Dashboard (rest, scrollable) ─
          Expanded(
            child: LostDogStatsPanel(
              reports: reports,
              totalScans: totalScans,
              onReportTap: (report) {
                LostDogDetailSheet.show(context, report, lostDogSvc);
              },
            ),
          ),
        ],
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
              const Text(
                'Report Sighting',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
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
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Optional note (e.g. direction heading)...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 13,
                  ),
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        final remoteSvc =
                            ref.read(supabaseLostDogServiceProvider);
                        if (remoteSvc != null) {
                          final position =
                              await _controller.fetchUserPosition();
                          if (position != null) {
                            await remoteSvc.reportSighting(
                              report.id,
                              position.latitude,
                              position.longitude,
                              note: noteController.text.isNotEmpty
                                  ? noteController.text
                                  : null,
                            );
                          }
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: bgCard,
                              content: Text(
                                'Sighting reported for ${report.dogName}!',
                                style: const TextStyle(
                                  color: Colors.orange,
                                ),
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LostDogMap extends StatelessWidget {
  final MapController mapController;
  final List<LostDogReport> reports;
  final List<LostDogReportRemote> remoteReports;
  final List<LostDogSightingRemote> liveSightings;
  final bool loadingRemote;
  final String? selectedReportId;
  final bool selectedIsRemote;
  final void Function(String reportId, bool isRemote) onMarkerTap;
  final VoidCallback onMapTap;
  final void Function(LostDogReportRemote report) onReportSighting;
  final void Function(LostDogReport report) onReportTap;

  const _LostDogMap({
    required this.mapController,
    required this.reports,
    required this.remoteReports,
    required this.liveSightings,
    required this.loadingRemote,
    required this.selectedReportId,
    required this.selectedIsRemote,
    required this.onMarkerTap,
    required this.onMapTap,
    required this.onReportSighting,
    required this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    final geoReports = reports
        .where((r) => r.lastSeenLat != null && r.lastSeenLon != null)
        .toList();

    final allLats = <double>[
      ...geoReports.map((r) => r.lastSeenLat!),
      ...remoteReports.map((r) => r.lastSeenLat),
    ];
    final allLons = <double>[
      ...geoReports.map((r) => r.lastSeenLon!),
      ...remoteReports.map((r) => r.lastSeenLon),
    ];

    LatLng center = const LatLng(40.7580, -73.9855);
    double zoom = 10.0;

    if (allLats.isNotEmpty) {
      allLats.sort();
      allLons.sort();
      center = LatLng(
        (allLats.first + allLats.last) / 2,
        (allLons.first + allLons.last) / 2,
      );
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
            mapController: mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              minZoom: 3,
              maxZoom: 18,
              onTap: (_, __) => onMapTap(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dogquest.app',
                fallbackUrl: 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              MarkerLayer(
                markers: [
                  ...geoReports.map(
                    (r) => _buildMarker(
                      r,
                      () => onMarkerTap(r.id, false),
                      onReportTap,
                    ),
                  ),
                  ...remoteReports.map(
                    (r) => _buildRemoteMarker(
                      r,
                      () => onMarkerTap(r.id, true),
                    ),
                  ),
                  ...liveSightings.map(_buildSightingMarker),
                ],
              ),
            ],
          ),
        ),
        if (loadingRemote)
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
                  Text(
                    'Loading cloud reports...',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (geoReports.isEmpty && remoteReports.isEmpty && !loadingRemote)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'No location data available',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reports need GPS coordinates to appear on the map',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        if (selectedReportId != null && !selectedIsRemote)
          _buildPopup(
            reports.firstWhere((r) => r.id == selectedReportId),
            onReportTap,
            () => onMapTap(),
          ),
        if (selectedReportId != null && selectedIsRemote)
          _buildRemotePopup(
            remoteReports.firstWhere((r) => r.id == selectedReportId),
            onReportSighting,
            () => onMapTap(),
          ),
        if (geoReports.isNotEmpty || remoteReports.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: _buildLegend(
              geoReports.isNotEmpty,
              remoteReports.isNotEmpty,
              liveSightings.isNotEmpty,
            ),
          ),
      ],
    );
  }

  Marker _buildMarker(
    LostDogReport report,
    VoidCallback onTap,
    void Function(LostDogReport) onDetailTap,
  ) {
    final color = _statusColor(report.status);

    return Marker(
      point: LatLng(report.lastSeenLat!, report.lastSeenLon!),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () {
          if (report.status == LostDogStatus.found) return;
          onTap();
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

  Marker _buildRemoteMarker(
    LostDogReportRemote report,
    VoidCallback onTap,
  ) {
    return Marker(
      point: LatLng(report.lastSeenLat, report.lastSeenLon),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: onTap,
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

  Widget _buildPopup(
    LostDogReport report,
    void Function(LostDogReport) onDetailTap,
    VoidCallback onClose,
  ) {
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
        onTap: () => onDetailTap(report),
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
                        Text(
                          'Tap for details',
                          style: TextStyle(
                            color: textSecondary.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: textSecondary.withValues(alpha: 0.6),
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: textSecondary, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemotePopup(
    LostDogReportRemote report,
    void Function(LostDogReportRemote) onReportSighting,
    VoidCallback onClose,
  ) {
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
                          if (report.distanceKm != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${report.distanceKm!.toStringAsFixed(1)} km',
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
                              '${report.sightingCount} sighting'
                              '${report.sightingCount == 1 ? '' : 's'}',
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
                IconButton(
                  icon: const Icon(Icons.close, color: textSecondary, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onReportSighting(report),
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

  Widget _buildLegend(
    bool hasLocal,
    bool hasRemote,
    bool hasSightings,
  ) {
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
          if (hasRemote) ...[
            const SizedBox(height: 4),
            _legendRow(Colors.blue, 'Cloud'),
          ],
          if (hasSightings) ...[
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
        Text(
          label,
          style: const TextStyle(color: textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

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
