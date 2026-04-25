import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants.dart';
import '../../models/dog_friendship.dart';
import '../../services/dog_friendship_service.dart';

class NeighborhoodGrid extends StatefulWidget {
  final List<NeighborhoodDog> neighborDogs;
  final List myDogs;
  final DogFriendshipService friendSvc;
  final NeighborhoodDog? selectedDog;
  final ValueChanged<NeighborhoodDog?> onDogSelected;

  const NeighborhoodGrid({
    required this.neighborDogs,
    required this.myDogs,
    required this.friendSvc,
    required this.selectedDog,
    required this.onDogSelected,
    super.key,
  });

  @override
  State<NeighborhoodGrid> createState() => _NeighborhoodGridState();
}

class _NeighborhoodGridState extends State<NeighborhoodGrid> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1A).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // Neighborhood label
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.park, color: Color(0xFFD4874E), size: 16),
                const SizedBox(width: 6),
                Text(
                  '${widget.myDogs.isNotEmpty ? widget.myDogs.first.name : "Your"} Park',
                  style: const TextStyle(
                    color: Color(0xFFD4874E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Refreshes weekly',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Grid
          ...List.generate(4, (row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: List.generate(4, (col) {
                  // Center 2x2 is "home"
                  if ((col == 1 || col == 2) && (row == 1 || row == 2)) {
                    if (col == 1 && row == 1) {
                      // Home cell
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onDogSelected(null),
                          child: Container(
                            height: 68,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.home,
                                    color: Colors.amber, size: 20),
                                const SizedBox(height: 2),
                                Text(
                                  'Home',
                                  style: TextStyle(
                                    color: Colors.amber.withValues(alpha: 0.7),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    // Other home cells — show user's dogs
                    final homeIdx = (col == 2 && row == 1)
                        ? 0
                        : (col == 1 && row == 2)
                            ? 1
                            : 2;
                    if (homeIdx < widget.myDogs.length) {
                      final dog = widget.myDogs[homeIdx];
                      return Expanded(
                        child: Container(
                          height: 68,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('\u{1F436}',
                                  style: TextStyle(fontSize: 18)),
                              Text(
                                dog.name,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Expanded(
                      child: Container(
                        height: 68,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }

                  // Neighbor cell
                  final neighbor = widget.neighborDogs
                      .where((d) => d.gridX == col && d.gridY == row)
                      .toList();
                  if (neighbor.isEmpty) {
                    return Expanded(
                      child: Container(
                        height: 68,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            [
                              Icons.park,
                              Icons.nature,
                              Icons.grass
                            ][((row * 4 + col) % 3)],
                            color: Colors.green.withValues(alpha: 0.08),
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  }

                  final dog = neighbor.first;
                  final friendship = widget.friendSvc.getFriendship(
                    widget.myDogs.isNotEmpty
                        ? (widget.myDogs.first as dynamic).name as String
                        : '',
                    dog.name,
                  );
                  final isSelected = widget.selectedDog?.name == dog.name;
                  final isFriend = friendship != null;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onDogSelected(dog);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 68,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7C4DFF).withValues(alpha: 0.15)
                              : isFriend
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF7C4DFF).withValues(alpha: 0.5)
                                : isFriend
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.transparent,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dog.emoji,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 1),
                            Text(
                              dog.name,
                              style: TextStyle(
                                color: isFriend ? Colors.green : Colors.white54,
                                fontSize: 9,
                                fontWeight: isFriend
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isFriend)
                              Text(
                                friendship.level.emoji,
                                style: const TextStyle(fontSize: 8),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 50.ms);
  }
}
