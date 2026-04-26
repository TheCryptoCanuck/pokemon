import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:dogquest/models/pack.dart';

/// A weekly activity summary card for the Pack.
class WeeklyPackReport extends StatelessWidget {
  final Pack pack;

  const WeeklyPackReport({super.key, required this.pack});

  @override
  Widget build(BuildContext context) {
    // Determine week label
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final weekLabel = '${_shortDate(monday)} - ${_shortDate(sunday)}';
    final dayOfWeek = now.weekday; // 1=Mon, 7=Sun

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C4DFF).withValues(alpha: 0.1),
            const Color(0xFF448AFF).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Color(0xFF7C4DFF), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Weekly Pack Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                weekLabel,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _reportStat(
                '\u{1F43E}',
                '${pack.weeklyBreedsFound}',
                'New Breeds',
                Colors.amber,
              ),
              const SizedBox(width: 10),
              _reportStat(
                '\u{26A1}',
                '${pack.weeklyXpEarned}',
                'XP Earned',
                const Color(0xFFD4874E),
              ),
              const SizedBox(width: 10),
              _reportStat(
                '\u{1F525}',
                '${pack.weeklyActiveDays}',
                'Active Days',
                const Color(0xFFFF9800),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Week progress bar (days of the week)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final isPast = i < dayOfWeek;
              final isToday = i == dayOfWeek - 1;
              final isActive = i < pack.weeklyActiveDays;
              return Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.amber.withValues(alpha: isToday ? 0.4 : 0.2)
                          : isPast
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: Colors.amber, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(
                              Icons.check,
                              color: Colors.amber,
                              size: 14,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayNames[i],
                    style: TextStyle(
                      color: isToday ? Colors.amber : Colors.white30,
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),

          // Motivational message
          if (pack.weeklyActiveDays < 7) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _motivationMessage(pack.weeklyActiveDays, dayOfWeek),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _reportStat(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}';
  }

  String _motivationMessage(int activeDays, int dayOfWeek) {
    final remaining = 7 - dayOfWeek;
    if (activeDays == 0) return 'Start spotting dogs to light up your week!';
    if (activeDays >= dayOfWeek) {
      return 'Perfect attendance so far! Keep it up for $remaining more day${remaining == 1 ? '' : 's'}.';
    }
    if (activeDays >= 5) {
      return 'Almost a full week! Just ${7 - activeDays} more day${7 - activeDays == 1 ? '' : 's'} to go.';
    }
    return 'Your pack has been active $activeDays day${activeDays == 1 ? '' : 's'} this week. Go explore together!';
  }
}
