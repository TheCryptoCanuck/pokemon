import 'package:flutter/material.dart';

import 'package:dogquest/models/pack.dart';
import 'package:dogquest/widgets/pack/member_card.dart';

class MembersSection extends StatelessWidget {
  final Pack pack;
  final VoidCallback onAddMember;
  final void Function(PackMember member) onRemoveMember;

  const MembersSection({
    required this.pack,
    required this.onAddMember,
    required this.onRemoveMember,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Pack Members',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const Spacer(),
            if (pack.members.length < 8)
              GestureDetector(
                onTap: onAddMember,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...pack.members.asMap().entries.map((entry) {
          final member = entry.value;
          return MemberCard(
            pack: pack,
            member: member,
            onRemove: () => onRemoveMember(member),
          );
        }),
      ],
    );
  }
}
