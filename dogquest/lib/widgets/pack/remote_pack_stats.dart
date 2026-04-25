import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants.dart';
import '../../services/supabase_pack_service.dart';
import 'pack_stat_card.dart';

class RemotePackStats extends StatelessWidget {
  final PackRemote pack;
  final List<PackMemberRemote> members;
  final List<PackDogRemote> dogs;

  const RemotePackStats({
    required this.pack,
    required this.members,
    required this.dogs,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pack Stats',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.amber)),
        const SizedBox(height: 12),
        Row(
          children: [
            PackStatCard(
                emoji: '\u{1F43E}',
                value: '${dogs.length}',
                label: 'Pack Dogs',
                color: Colors.amber),
            const SizedBox(width: 10),
            PackStatCard(
                emoji: '\u{1F465}',
                value: '${members.length}',
                label: 'Members',
                color: const Color(0xFFD4874E)),
            const SizedBox(width: 10),
            PackStatCard(
                emoji: '\u{1F4AC}',
                value: pack.inviteCode,
                label: 'Code',
                color: const Color(0xFF7C4DFF)),
          ],
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }
}
