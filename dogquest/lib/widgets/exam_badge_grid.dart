import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/exam_result.dart';
import 'package:dogquest/services/exam_service.dart';
import 'package:dogquest/services/dog_group_service.dart';

/// Compact grid showing earned breed group certifications on the profile screen.
class ExamBadgeGrid extends ConsumerWidget {
  const ExamBadgeGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examSvc = ref.read(examServiceProvider);
    final summaries = examSvc.allGroupSummaries;

    // Only show if at least one cert earned.
    final hasCerts = summaries.any((s) => s.highestTier != null);
    if (!hasCerts) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
            const SizedBox(width: 6),
            const Text(
              'Certifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (examSvc.isCanineScholar)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: examGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: examGold.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '\u{1F393} Canine Scholar',
                  style: TextStyle(
                    color: examGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: summaries.map((s) => _BadgeChip(summary: s)).toList(),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final GroupExamSummary summary;

  const _BadgeChip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final group = families.firstWhere((g) => g.id == summary.groupId);
    final tier = summary.highestTier;

    if (tier == null) {
      // No certification — dim chip.
      return Opacity(
        opacity: 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${group.emoji} ${group.name.replaceAll(" Group", "")}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }

    final tierColor = switch (tier) {
      ExamTier.gold => examGold,
      ExamTier.silver => examSilver,
      ExamTier.bronze => examBronze,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tierColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tier.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            group.name.replaceAll(' Group', ''),
            style: TextStyle(
              color: tierColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
