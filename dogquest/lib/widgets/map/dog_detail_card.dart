import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog_friendship.dart';
import 'package:dogquest/services/dog_friendship_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/widgets/network_dog_image.dart';

class DogDetailCard extends ConsumerWidget {
  final NeighborhoodDog dog;
  final List myDogs;
  final DogFriendshipService friendSvc;
  final VoidCallback onFriendshipChanged;

  const DogDetailCard({
    required this.dog,
    required this.myDogs,
    required this.friendSvc,
    required this.onFriendshipChanged,
    super.key,
  });

  String _nextLevelLabel(DogFriendship f) {
    final next = FriendshipLevel.values
        .where((l) => l.visitsRequired > f.visits)
        .toList();
    return next.isNotEmpty ? next.first.label : 'Max';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myDogName =
        myDogs.isNotEmpty ? (myDogs.first as dynamic).name as String : '';
    final friendship = friendSvc.getFriendship(myDogName, dog.name);
    final dogSvc = ref.read(dogServiceProvider);
    final breedDog = dogSvc.lookup(dog.breed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(dog.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dog.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      dog.breed,
                      style: const TextStyle(color: Colors.amber, fontSize: 13),
                    ),
                    Text(
                      dog.personality,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (friendship != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        friendship.level.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        friendship.level.label,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Breed image if available
          if (breedDog != null && breedDog.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NetworkDogImage(url: breedDog.imageUrl, height: 120),
            ),
          ],

          const SizedBox(height: 12),

          // Friendship status / actions
          if (friendship == null) ...[
            // Not friends yet
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: myDogName.isEmpty
                    ? null
                    : () {
                        friendSvc.befriend(myDogName, dog);
                        ref.read(playerProvider.notifier).awardBonusXp(10);
                        onFriendshipChanged();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: bgCard,
                            content: Text(
                              '${dog.name} and $myDogName are now friends! +10 XP',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.favorite, size: 18),
                label: Text('Befriend ${dog.name}'),
              ),
            ),
          ] else ...[
            // Friends — show progress + visit button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Visits: ${friendship.visits}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          if (friendship.visitsToNextLevel > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${friendship.visitsToNextLevel} to ${_nextLevelLabel(friendship)}',
                              style: const TextStyle(
                                color: Colors.white30,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: friendship.progressToNextLevel,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            friendship.level == FriendshipLevel.bestFriend
                                ? Colors.amber
                                : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: friendship.canVisitToday
                      ? () {
                          final leveled = friendSvc.visit(myDogName, dog.name);
                          if (leveled) {
                            ref.read(playerProvider.notifier).awardBonusXp(5);
                            onFriendshipChanged();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: bgCard,
                                content: Text(
                                  'Visited ${dog.name}! +5 XP',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: friendship.canVisitToday
                        ? Colors.green
                        : Colors.white12,
                    foregroundColor: friendship.canVisitToday
                        ? Colors.white
                        : Colors.white38,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(friendship.canVisitToday ? 'Visit!' : 'Visited'),
                ),
              ],
            ),
            if (friendship.level.xpBonus > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${friendship.level.emoji} ${friendship.level.label} — +${(friendship.level.xpBonus * 100).toInt()}% XP bonus on sightings',
                  style: const TextStyle(color: Colors.amber, fontSize: 11),
                ),
              ),
            ],
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }
}
