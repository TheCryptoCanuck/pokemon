import 'package:flutter/material.dart';

import 'package:dogquest/services/dog_mastery_service.dart';

class MasterySummary extends StatelessWidget {
  final DogMasteryState mastery;
  final int totalDogs;

  const MasterySummary({
    required this.mastery,
    required this.totalDogs,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final levels = [
      (DogMasteryLevel.master, mastery.totalMastered),
      (DogMasteryLevel.expert, mastery.totalExpert),
      (DogMasteryLevel.familiar, mastery.totalFamiliar),
      (DogMasteryLevel.spotted, mastery.totalSpotted),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mastery',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        ...levels.map((entry) {
          final (level, count) = entry;
          final fraction = totalDogs > 0 ? count / totalDogs : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(level.icon, color: level.color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            level.label,
                            style: TextStyle(
                              color: level.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: level.color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(level.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(
          '${mastery.sightingCounts.length}/$totalDogs tracked',
          style: const TextStyle(color: Colors.white30, fontSize: 10),
        ),
      ],
    );
  }
}
