import 'package:flutter/material.dart';

/// Show a themed SnackBar for a newly unlocked achievement.
///
/// [achievement] is a record of (emoji, name, description) matching the
/// achievements map in constants.dart.
void showAchievementSnackBar(
  BuildContext context,
  (String, String, String) achievement,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF2A1F1A),
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          Text(achievement.$1, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Achievement Unlocked!',
                style:
                    TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
              Text(achievement.$2,
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    ),
  );
}
