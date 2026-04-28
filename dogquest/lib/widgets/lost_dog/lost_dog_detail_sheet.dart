import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/lost_dog_report.dart';
import 'package:dogquest/services/lost_dog_service.dart';

class LostDogDetailSheet extends StatelessWidget {
  final LostDogReport report;
  final LostDogService lostDogService;

  const LostDogDetailSheet({
    required this.report,
    required this.lostDogService,
    super.key,
  });

  static Future<void> show(
    BuildContext context,
    LostDogReport report,
    LostDogService lostDogService,
  ) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
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
                  child: _PhotoPlaceholder.forReport(report),
                ),
              ),
              const SizedBox(height: 16),

              // Name + status
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
                  _StatusBadge(report.status),
                ],
              ),
              if (report.breed != null) ...[
                const SizedBox(height: 4),
                Text(
                  report.breed!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Info rows
              _InfoRow(
                Icons.schedule,
                Colors.red.shade300,
                'Missing Since',
                _formatInfoRow(report),
              ),
              if (report.lastSeenLocation != null)
                _InfoRow(
                  Icons.location_on,
                  Colors.amber,
                  'Last Seen',
                  report.lastSeenLocation!,
                ),
              if (report.lastSeenLat != null && report.lastSeenLon != null)
                _InfoRow(
                  Icons.map_outlined,
                  Colors.blue.shade300,
                  'GPS',
                  '${report.lastSeenLat!.toStringAsFixed(4)}, '
                      '${report.lastSeenLon!.toStringAsFixed(4)}',
                ),
              _InfoRow(
                Icons.calendar_today,
                Colors.white38,
                'Reported',
                _formatDate(report.createdAt),
              ),

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
                            const Text(
                              'Owner Contact',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              report.ownerContact!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
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
                      const Text(
                        'Description & Notes',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.notes!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Share poster action
              _ActionTile(
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
                _ActionTile(
                  icon: Icons.celebration,
                  iconColor: Colors.green,
                  label: 'Mark as Found',
                  subtitle: 'Great news! This dog has been reunited.',
                  onTap: () {
                    lostDogService.markFound(report.id);
                    Navigator.pop(ctx);
                    context.push(
                      '/reunion-celebration?'
                      'dogName=${Uri.encodeComponent(report.dogName)}&'
                      'reportId=${report.id}',
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError('Use LostDogDetailSheet.show() instead');
  }
}

String _formatInfoRow(LostDogReport report) {
  final daysAgo = DateTime.now().difference(report.lostDate).inDays;
  return '${_formatDate(report.lostDate)} '
      '($daysAgo day${daysAgo == 1 ? '' : 's'} ago)';
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

class _PhotoPlaceholder extends StatelessWidget {
  final LostDogReport report;

  const _PhotoPlaceholder(this.report);

  /// Factory that returns either an Image.file or the placeholder widget.
  /// Named `forReport` (not `build`) to avoid shadowing the inherited
  /// StatelessWidget.build(BuildContext).
  static Widget forReport(LostDogReport report) {
    final hasPhoto = report.photoPath != null &&
        report.photoPath!.isNotEmpty &&
        File(report.photoPath!).existsSync();

    return hasPhoto
        ? Image.file(
            File(report.photoPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _PhotoPlaceholder(report),
          )
        : _PhotoPlaceholder(report);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.amber.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pets,
              color: Colors.amber.withValues(alpha: 0.4),
              size: 64,
            ),
            const SizedBox(height: 8),
            Text(
              'No photo available',
              style: TextStyle(
                color: Colors.amber.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LostDogStatus status;

  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow(
    this.icon,
    this.iconColor,
    this.label,
    this.value,
  );

  @override
  Widget build(BuildContext context) {
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
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                child: Center(
                  child: Icon(icon, color: iconColor, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
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
