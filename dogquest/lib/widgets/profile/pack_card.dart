import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/services/pack_service.dart';

class PackCard extends ConsumerWidget {
  const PackCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packSvc = ref.read(packServiceProvider);
    final pack = packSvc.pack;

    if (pack == null) {
      // No pack — show CTA
      return GestureDetector(
        onTap: () => context.push('/pack'),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4, bottom: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                const Color(0xFF448AFF).withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.group_add,
                  color: Color(0xFF7C4DFF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a Pack',
                      style: TextStyle(
                        color: Color(0xFF7C4DFF),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Create a family group to share dogs & track stats together',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF7C4DFF),
                size: 14,
              ),
            ],
          ),
        ),
      ).animate().fadeIn().slideY(begin: 0.05);
    }

    // Show pack summary
    return GestureDetector(
      onTap: () => context.push('/pack'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(pack.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pack.members.length} member${pack.members.length == 1 ? '' : 's'} • ${pack.totalDogs} dog${pack.totalDogs == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (pack.weeklyActiveDays > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${pack.weeklyActiveDays}/7',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}
