import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/exam_result.dart';
import 'package:dogquest/services/exam_service.dart';
import 'package:dogquest/services/dog_group_service.dart';

/// Horizontal scrollable row of breed group exam cards for the Field Guide.
class ExamGroupRow extends ConsumerWidget {
  const ExamGroupRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examSvc = ref.read(examServiceProvider);
    final summaries = examSvc.allGroupSummaries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            'Breed Group Exams',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: summaries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final s = summaries[index];
              return _ExamCard(summary: s);
            },
          ),
        ),
      ],
    );
  }
}

class _ExamCard extends ConsumerWidget {
  final GroupExamSummary summary;

  const _ExamCard({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = families.firstWhere((g) => g.id == summary.groupId);
    final hasGold = summary.highestTier == ExamTier.gold;
    final nextTier = summary.nextTier;
    final onCooldown = summary.isOnCooldown;

    // Badge color
    final tierColor = switch (summary.highestTier) {
      ExamTier.gold => examGold,
      ExamTier.silver => examSilver,
      ExamTier.bronze => examBronze,
      null => Colors.white24,
    };

    return GestureDetector(
      onTap: () {
        if (hasGold || nextTier == null || onCooldown) {
          // Show info or cooldown message
          if (onCooldown) {
            final remaining = ref.read(examServiceProvider).remainingCooldown(
                  summary.groupId,
                  nextTier!,
                );
            final mins = remaining.inMinutes;
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cooldown: retry in ${mins > 60 ? "${mins ~/ 60}h ${mins % 60}m" : "${mins}m"}',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        HapticFeedback.mediumImpact();
        context.push(
          '/quiz?examGroup=${summary.groupId}&examTier=${nextTier.name}',
        );
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: group.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasGold
                ? examGold.withValues(alpha: 0.5)
                : group.color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(group.emoji, style: const TextStyle(fontSize: 18)),
                const Spacer(),
                if (summary.highestTier != null)
                  Text(
                    summary.highestTier!.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              group.name.replaceAll(' Group', ''),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (hasGold)
              Text(
                'Mastered!',
                style: TextStyle(
                  color: examGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (onCooldown)
              const Text(
                'On cooldown',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              )
            else if (nextTier != null)
              Text(
                'Take ${nextTier.label}',
                style: TextStyle(
                  color: tierColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const Text(
                'Start exam',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
