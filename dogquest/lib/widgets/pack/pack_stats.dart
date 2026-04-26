import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dogquest/models/pack.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/widgets/pack/pack_stat_card.dart';

class PackStats extends ConsumerWidget {
  final Pack pack;

  const PackStats({required this.pack, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kennelSvc = ref.read(kennelServiceProvider);
    final playerState = ref.watch(playerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pack Stats',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PackStatCard(
              emoji: '\u{1F43E}',
              value: '${pack.totalDogs}',
              label: 'Pack Dogs',
              color: Colors.amber,
            ),
            const SizedBox(width: 10),
            PackStatCard(
              emoji: '\u{1F4DA}',
              value: '${kennelSvc.count}',
              label: 'Breeds Found',
              color: const Color(0xFFD4874E),
            ),
            const SizedBox(width: 10),
            PackStatCard(
              emoji: '\u{26A1}',
              value: '${playerState.level}',
              label: 'Pack Level',
              color: const Color(0xFF7C4DFF),
            ),
          ],
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }
}
