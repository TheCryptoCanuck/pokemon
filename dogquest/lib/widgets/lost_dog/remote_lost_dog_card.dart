import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants.dart';
import '../../services/supabase_lost_dog_service.dart';

class RemoteLostDogCard extends StatelessWidget {
  final LostDogReportRemote report;

  const RemoteLostDogCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final daysAgo = DateTime.now().difference(report.lastSeenAt).inDays;
    final timeLabel = daysAgo == 0
        ? 'Today'
        : daysAgo == 1
            ? '1 day ago'
            : '$daysAgo days ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Cloud photo placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: report.photoUrl != null
                    ? Image.network(
                        report.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.blue.withValues(alpha: 0.08),
                          child: const Center(
                            child:
                                Icon(Icons.cloud, color: Colors.blue, size: 30),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.blue.withValues(alpha: 0.08),
                        child: const Center(
                          child:
                              Icon(Icons.cloud, color: Colors.blue, size: 30),
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
                      // Cloud-only badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud,
                                color: Colors.blue.shade300, size: 11),
                            const SizedBox(width: 3),
                            Text(
                              'Cloud',
                              style: TextStyle(
                                color: Colors.blue.shade300,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (report.breed.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      report.breed,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
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
                        'Missing $timeLabel',
                        style:
                            TextStyle(color: Colors.red.shade300, fontSize: 12),
                      ),
                    ],
                  ),
                  if (report.distanceMiles != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.near_me,
                            color: Colors.white38, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          '${report.distanceMiles!.toStringAsFixed(1)} mi away',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.03);
  }
}
