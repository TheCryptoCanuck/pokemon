import 'package:flutter/material.dart';

import 'package:dogquest/models/dog_friendship.dart';
import 'package:dogquest/services/dog_friendship_service.dart';

class FriendsList extends StatelessWidget {
  final DogFriendshipService friendSvc;

  const FriendsList({
    required this.friendSvc,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final friendships = friendSvc.friendships;
    if (friendships.isEmpty) return const SizedBox.shrink();

    // Group by level
    final bestFriends = friendships
        .where((f) => f.level == FriendshipLevel.bestFriend)
        .toList();
    final friends =
        friendships.where((f) => f.level == FriendshipLevel.friend).toList();
    final others = friendships
        .where(
          (f) =>
              f.level == FriendshipLevel.acquaintance ||
              f.level == FriendshipLevel.newNeighbor,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.favorite, color: Colors.green, size: 18),
            SizedBox(width: 6),
            Text(
              'Dog Friends',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (bestFriends.isNotEmpty)
          _FriendshipGroup(
            title: 'Best Friends \u{1F31F}',
            friendships: bestFriends,
            color: Colors.amber,
          ),
        if (friends.isNotEmpty)
          _FriendshipGroup(
            title: 'Friends \u{1F496}',
            friendships: friends,
            color: Colors.green,
          ),
        if (others.isNotEmpty)
          _FriendshipGroup(
            title: 'Getting to Know \u{1F44B}',
            friendships: others,
            color: Colors.white38,
          ),
      ],
    );
  }
}

class _FriendshipGroup extends StatelessWidget {
  final String title;
  final List<DogFriendship> friendships;
  final Color color;

  const _FriendshipGroup({
    required this.title,
    required this.friendships,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: friendships
              .map(
                (f) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        f.neighborEmoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        f.neighborDogName,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (f.canVisitToday) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
