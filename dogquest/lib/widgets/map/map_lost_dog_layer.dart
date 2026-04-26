import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dogquest/models/lost_dog_report.dart';

/// A [MarkerLayer] that renders lost dog report pins on a FlutterMap.
///
/// Each pin is color-coded by report status:
/// - Red: actively lost
/// - Amber: sighting reported
/// - Green: reunited
///
/// This widget can be added as a child of any [FlutterMap] to overlay
/// lost dog pins alongside sighting markers.
class MapLostDogLayer extends StatelessWidget {
  final List<LostDogReport> reports;
  final ValueChanged<LostDogReport>? onReportTapped;

  const MapLostDogLayer({
    super.key,
    required this.reports,
    this.onReportTapped,
  });

  @override
  Widget build(BuildContext context) {
    final markers = reports
        .where((r) => r.lastSeenLat != null && r.lastSeenLon != null)
        .map((r) {
      final color = _statusColor(r.status);
      return Marker(
        width: 40,
        height: 40,
        point: LatLng(r.lastSeenLat!, r.lastSeenLon!),
        child: GestureDetector(
          onTap: () => onReportTapped?.call(r),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
            child: Icon(
              r.status == LostDogStatus.found
                  ? Icons.check_circle
                  : Icons.warning_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }

  Color _statusColor(LostDogStatus status) {
    switch (status) {
      case LostDogStatus.active:
        return Colors.red;
      case LostDogStatus.found:
        return Colors.green;
      case LostDogStatus.cancelled:
        return Colors.grey;
    }
  }
}
