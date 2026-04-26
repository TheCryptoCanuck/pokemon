import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/pack.dart';
import 'package:dogquest/services/my_dog_service.dart';

class MemberCard extends ConsumerWidget {
  final Pack pack;
  final PackMember member;
  final VoidCallback onRemove;

  const MemberCard({
    required this.pack,
    required this.member,
    required this.onRemove,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myDogSvc = ref.read(myDogServiceProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: member.isAlpha
              ? Colors.amber.withValues(alpha: 0.3)
              : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: member.isAlpha
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    member.avatarEmoji ?? '\u{1F9D1}',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (member.isAlpha) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Alpha',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${member.dogNames.length} dog${member.dogNames.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!member.isAlpha)
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white24, size: 18),
                  onPressed: onRemove,
                  tooltip: 'Remove',
                ),
            ],
          ),
          // Dog names
          if (member.dogNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: member.dogNames.map((name) {
                final dogProfile = myDogSvc.getDog(name);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pets, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      if (dogProfile?.breed != null) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(color: Colors.white24, fontSize: 11),
                        ),
                        Text(
                          dogProfile!.breed!,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn();
  }
}
