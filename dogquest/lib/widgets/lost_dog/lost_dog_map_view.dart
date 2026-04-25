import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../constants.dart';
import '../../models/lost_dog_report.dart';
import '../../services/supabase_lost_dog_service.dart';

class LostDogMapView extends StatefulWidget {
  final MapController mapController;
  final List<LostDogReport> localReports;
  final List<LostDogReportRemote> remoteReports;
  final List<LostDogSightingRemote> liveSightings;
  final bool loadingRemote;
  final String? selectedReportId;
  final bool selectedIsRemote;
  final Function(String id, bool isRemote) onMarkerTap;
  final VoidCallback onMapTap;
  final Function(String reportId) onSubscribeToSightings;
  final Function(BuildContext context, LostDogReport report) onShowReportDetail;
  final Function(LostDogReportRemote report) onShowRemotePopup;

  const LostDogMapView({
    required this.mapController,
    required this.localReports,
    required this.remoteReports,
    required this.liveSightings,
    required this.loadingRemote,
    required this.selectedReportId,
    required this.selectedIsRemote,
    required this.onMarkerTap,
    required this.onMapTap,
    required this.onSubscribeToSightings,
    required this.onShowReportDetail,
    required this.onShowRemotePopup,
  });

  @override
  State<LostDogMapView> createState() => _LostDogMapViewState();
}

class _LostDogMapViewState extends State<LostDogMapView> {
  // NYC default center for demo data.
  static const _defaultCenter = LatLng(40.7580, -73.9855);
  static const _defaultZoom = 10.0;

  @override
  Widget build(BuildContext context) {
    // Compute center from reports with GPS, or use default.
    final geoReports = widget.localReports
        .where((r) => r.lastSeenLat != null && r.lastSeenLon != null)
        .toList();

    // Collect all lat/lons including remote reports for centering.
    final allLats = <double>[
      ...geoReports.map((r) => r.lastSeenLat!),
      ...widget.remoteReports.map((r) => r.lastSeenLat),
    ];
    final allLons = <double>[
      ...geoReports.map((r) => r.lastSeenLon!),
      ...widget.remoteReports.map((r) => r.lastSeenLon),
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
            mapController: widget.mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              minZoom: 3,
              maxZoom: 18,
              onTap: (_, __) => widget.onMapTap(),
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
                  ...widget.remoteReports.map(_buildRemoteMarker),
                  ...widget.liveSightings.map(_buildSightingMarker),
                ],
              ),
            ],
          ),
        ),
        // Loading indicator for remote reports
        if (widget.loadingRemote)
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
        if (geoReports.isEmpty &&
            widget.remoteReports.isEmpty &&
            !widget.loadingRemote)
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
        if (widget.selectedReportId != null && !widget.selectedIsRemote)
          _buildPopup(
            widget.localReports
                .firstWhere((r) => r.id == widget.selectedReportId),
          ),
        if (widget.selectedReportId != null && widget.selectedIsRemote)
          widget.onShowRemotePopup(
            widget.remoteReports
                .firstWhere((r) => r.id == widget.selectedReportId),
          ),
        // Legend overlay
        if (geoReports.isNotEmpty || widget.remoteReports.isNotEmpty)
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
          if (report.status == LostDogStatus.found) return;
          widget.onMarkerTap(report.id, false);
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

  Marker _buildRemoteMarker(LostDogReportRemote report) {
    return Marker(
      point: LatLng(report.lastSeenLat, report.lastSeenLon),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () {
          widget.onMarkerTap(report.id, true);
          widget.onSubscribeToSightings(report.id);
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
        onTap: () => widget.onShowReportDetail(context, report),
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
                onPressed: () => widget.onMapTap(),
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
          if (widget.remoteReports.isNotEmpty) ...[
            const SizedBox(height: 4),
            _legendRow(Colors.blue, 'Cloud'),
          ],
          if (widget.liveSightings.isNotEmpty) ...[
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
}
