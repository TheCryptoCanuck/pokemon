import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants.dart';
import '../../services/dog_friendship_service.dart';

class FriendshipStatsBar extends StatelessWidget {
  final DogFriendshipService friendSvc;

  const FriendshipStatsBar({
    required this.friendSvc,
    super.key,
  });

  String _weekNumber() {
    final now = DateTime.now();
    final jan1 = DateTime(now.year, 1, 1);
    return '${((now.difference(jan1).inDays) ~/ 7) + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final total = friendSvc.totalFriendships;
    final bestFriends = friendSvc.bestFriendCount;
    return Row(
      children: [
        _MiniStat(emoji: '\u{1F43E}', value: '$total', label: 'Friends'),
        const SizedBox(width: 8),
        _MiniStat(
            emoji: '\u{1F31F}', value: '$bestFriends', label: 'Best Friends'),
        const SizedBox(width: 8),
        _MiniStat(
            emoji: '\u{1F3D8}', value: 'Wk ${_weekNumber()}', label: 'Season'),
      ],
    ).animate().fadeIn();
  }
}

class _MiniStat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _MiniStat({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
}
