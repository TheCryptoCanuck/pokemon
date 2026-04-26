import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../constants.dart';
import '../../models/lost_dog_report.dart';
import '../../services/lost_dog_service.dart';
import 'bottom_sheet_action.dart';

class LostDogReportCard extends StatelessWidget {
  final LostDogReport report;
  final LostDogService lostDogSvc;
  final VoidCallback onChanged;
  final bool hasCloudSync;

  const LostDogReportCard({
    required this.report,
    required this.lostDogSvc,
    required this.onChanged,
    this.hasCloudSync = false,
  });

  String _daysSince(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return '1 day ago';
    return '$diff days ago';
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

  @override
  Widget build(BuildContext context) {
    final hasPhoto = report.photoPath != null &&
        report.photoPath!.isNotEmpty &&
        File(report.photoPath!).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: report.status == LostDogStatus.found
              ? null
              : () => _showReportOptions(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: report.status == LostDogStatus.found
                ? Row(
                    children: [
                      // Greyed-out placeholder for reunited dogs
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Container(
                            color: Colors.green.withValues(alpha: 0.08),
                            child: const Center(
                              child: Icon(Icons.pets,
                                  color: Colors.green, size: 30),
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
                                const Expanded(
                                  child: Text(
                                    'Reunited',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _buildStatusBadge(),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This dog has been safely returned to their owner.',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Dog photo or placeholder
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: hasPhoto
                              ? Image.file(
                                  File(report.photoPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _photoPlaceholder(),
                                )
                              : _photoPlaceholder(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.dogName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasCloudSync)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Tooltip(
                                      message: 'Synced to cloud',
                                      child: Icon(Icons.cloud_done,
                                          color: Colors.blue.shade300,
                                          size: 16),
                                    ),
                                  ),
                                _buildStatusBadge(),
                              ],
                            ),
                            if (report.breed != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                report.breed!,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.schedule,
                                    color: Colors.red.shade300, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Missing since ${_formatDate(report.lostDate)}',
                                  style: TextStyle(
                                    color: Colors.red.shade300,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _daysSince(report.lostDate),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            if (report.lastSeenLocation != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.white38, size: 13),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      report.lastSeenLocation!,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: Colors.white24, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.03);
  }

  Widget _photoPlaceholder() {
    return Container(
      color: Colors.amber.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.pets, color: Colors.amber, size: 30),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color badgeColor;
    Color textColor;
    String label;

    switch (report.status) {
      case LostDogStatus.active:
        badgeColor = Colors.red;
        textColor = Colors.red.shade300;
        label = 'Missing';
        break;
      case LostDogStatus.found:
        badgeColor = Colors.green;
        textColor = Colors.green.shade300;
        label = 'Reunited';
        break;
      case LostDogStatus.cancelled:
        badgeColor = Colors.grey;
        textColor = Colors.grey.shade300;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showReportOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final hasPhoto = report.photoPath != null &&
            report.photoPath!.isNotEmpty &&
            File(report.photoPath!).existsSync();
        final daysAgo = DateTime.now().difference(report.lostDate).inDays;

        return DraggableScrollableSheet(
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

                // ── Photo ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: hasPhoto
                        ? Image.file(
                            File(report.photoPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _detailPhotoPlaceholder(),
                          )
                        : _detailPhotoPlaceholder(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Name + status ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.dogName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    _buildStatusBadge(),
                  ],
                ),
                if (report.breed != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    report.breed!,
                    style: const TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ],
                const SizedBox(height: 20),

                // ── Info grid ──
                _detailRow(Icons.schedule, Colors.red.shade300, 'Missing Since',
                    '${_formatDate(report.lostDate)} ($daysAgo day${daysAgo == 1 ? '' : 's'} ago)'),
                if (report.lastSeenLocation != null)
                  _detailRow(Icons.location_on, Colors.amber, 'Last Seen',
                      report.lastSeenLocation!),
                if (report.lastSeenLat != null && report.lastSeenLon != null)
                  _detailRow(Icons.map_outlined, Colors.blue.shade300, 'GPS',
                      '${report.lastSeenLat!.toStringAsFixed(4)}, ${report.lastSeenLon!.toStringAsFixed(4)}'),
                _detailRow(Icons.calendar_today, Colors.white38, 'Reported',
                    _formatDate(report.createdAt)),

                // ── Owner contact ──
                if (report.ownerContact != null &&
                    report.ownerContact!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone,
                            color: Colors.amber.shade300, size: 20),
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
                              Text(
                                report.ownerContact!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Notes ──
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
                        Text(
                          report.notes!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Actions ──
                // Share poster
                BottomSheetAction(
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
                // View on map
                BottomSheetAction(
                  icon: Icons.map,
                  iconColor: Colors.blue.shade300,
                  label: 'View on Map',
                  subtitle: 'See last known location on the network map',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/lost-dog/map');
                  },
                ),
                const SizedBox(height: 8),
                // Mark as Found
                BottomSheetAction(
                  icon: Icons.celebration,
                  iconColor: Colors.green,
                  label: 'Mark as Found',
                  subtitle: 'Great news! This dog has been reunited.',
                  onTap: () {
                    lostDogSvc.markFound(report.id);
                    Navigator.pop(ctx);
                    onChanged();
                    context.push(
                      '/reunion-celebration?dogName=${Uri.encodeComponent(report.dogName)}&reportId=${report.id}',
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Cancel Report
                BottomSheetAction(
                  icon: Icons.cancel_outlined,
                  iconColor: Colors.red.shade300,
                  label: 'Cancel Report',
                  subtitle: 'Remove this report from the active list.',
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmCancel(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailPhotoPlaceholder() {
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

  Widget _detailRow(
      IconData icon, Color iconColor, String label, String value) {
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

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Cancel Report?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove the lost report for ${report.dogName}? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              lostDogSvc.cancelReport(report.id);
              Navigator.pop(ctx);
              onChanged();
            },
            child: const Text('Cancel Report',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
