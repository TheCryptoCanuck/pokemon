import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/lost_dog_report.dart';

class StatsDashboard extends StatelessWidget {
  final List<LostDogReport> reports;
  final int totalScans;

  const StatsDashboard({
    required this.reports,
    required this.totalScans,
  });

  @override
  Widget build(BuildContext context) {
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
          onTap: report.status == LostDogStatus.found ? null : () {},
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
