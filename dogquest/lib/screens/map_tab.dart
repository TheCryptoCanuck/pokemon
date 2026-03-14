import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:latlong2/latlong.dart';
import '../constants.dart';
import '../models/dog_friendship.dart';
import '../services/dog_friendship_service.dart';
import '../services/dog_service.dart';
import '../services/my_dog_service.dart';
import '../services/player_service.dart';
import '../services/sighting_service.dart';
import '../widgets/dog_detail_sheet.dart';
import '../widgets/network_dog_image.dart';

class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  int _selectedTab = 0; // 0=Neighborhood, 1=Sighting Log, 2=Breed Map, 3=Live Map

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle bar
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              _tabButton('Hood', Icons.location_city, 0),
              const SizedBox(width: 6),
              _tabButton('Log', Icons.history, 1),
              const SizedBox(width: 6),
              _tabButton('Breeds', Icons.map_outlined, 2),
              const SizedBox(width: 6),
              _tabButton('Live Map', Icons.satellite_alt, 3),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _selectedTab == 0
              ? _NeighborhoodView()
              : _selectedTab == 1
                  ? _SightingLogView()
                  : _selectedTab == 2
                      ? _BreedLocationsView()
                      : _LiveMapView(),
        ),
      ],
    );
  }

  Widget _tabButton(String label, IconData icon, int tabIndex) {
    final selected = _selectedTab == tabIndex;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedTab = tabIndex);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.withValues(alpha: 0.15) : bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.amber : Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? Colors.amber : Colors.white54, size: 16),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            color: selected ? Colors.amber : Colors.white54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Neighborhood View
// ═══════════════════════════════════════════════════════════════════════

class _NeighborhoodView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NeighborhoodView> createState() => _NeighborhoodViewState();
}

class _NeighborhoodViewState extends ConsumerState<_NeighborhoodView> {
  NeighborhoodDog? _selectedDog;

  @override
  Widget build(BuildContext context) {
    final friendSvc = ref.read(dogFriendshipServiceProvider);
    final myDogSvc = ref.read(myDogServiceProvider);
    final neighborDogs = friendSvc.getNeighborhoodDogs();
    final myDogs = myDogSvc.dogs;

    if (myDogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('\u{1F3D8}', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Your Neighborhood',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              'Add your dog in the Profile tab to explore the neighborhood and make friends!',
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ]).animate().fadeIn(),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Friendship stats bar
          _buildFriendshipStats(friendSvc),
          const SizedBox(height: 12),

          // Neighborhood grid
          _buildNeighborhoodGrid(neighborDogs, myDogs, friendSvc),
          const SizedBox(height: 16),

          // Selected dog detail or instructions
          if (_selectedDog != null)
            _buildDogDetail(_selectedDog!, myDogs, friendSvc)
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(children: [
                Icon(Icons.touch_app, color: Colors.white38, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Tap a dog in the neighborhood to meet them!',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              ]),
            ).animate().fadeIn(),

          const SizedBox(height: 16),

          // Friends list
          _buildFriendsList(friendSvc),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFriendshipStats(DogFriendshipService friendSvc) {
    final total = friendSvc.totalFriendships;
    final bestFriends = friendSvc.bestFriendCount;
    return Row(
      children: [
        _miniStat('\u{1F43E}', '$total', 'Friends'),
        const SizedBox(width: 8),
        _miniStat('\u{1F31F}', '$bestFriends', 'Best Friends'),
        const SizedBox(width: 8),
        _miniStat('\u{1F3D8}', 'Wk ${_weekNumber()}', 'Season'),
      ],
    ).animate().fadeIn();
  }

  Widget _miniStat(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _buildNeighborhoodGrid(
    List<NeighborhoodDog> neighborDogs,
    List myDogs,
    DogFriendshipService friendSvc,
  ) {
    // 4x4 grid with neighborhood dogs and home in center
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
            child: Row(children: [
              const Icon(Icons.park, color: Color(0xFFD4874E), size: 16),
              const SizedBox(width: 6),
              Text('${myDogs.isNotEmpty ? myDogs.first.name : "Your"} Park',
                  style: const TextStyle(color: Color(0xFFD4874E), fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Refreshes weekly', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10)),
            ]),
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
                      // Home cell (spans conceptually but we just show in one cell)
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDog = null),
                          child: Container(
                            height: 68,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.home, color: Colors.amber, size: 20),
                              const SizedBox(height: 2),
                              Text('Home', style: TextStyle(color: Colors.amber.withValues(alpha: 0.7), fontSize: 9)),
                            ]),
                          ),
                        ),
                      );
                    }
                    // Other home cells — show user's dogs
                    final homeIdx = (col == 2 && row == 1) ? 0 : (col == 1 && row == 2) ? 1 : 2;
                    if (homeIdx < myDogs.length) {
                      final dog = myDogs[homeIdx];
                      return Expanded(
                        child: Container(
                          height: 68,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Text('\u{1F436}', style: TextStyle(fontSize: 18)),
                            Text(dog.name, style: const TextStyle(color: Colors.amber, fontSize: 9),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ]),
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
                  final neighbor = neighborDogs.where((d) => d.gridX == col && d.gridY == row).toList();
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
                            [Icons.park, Icons.nature, Icons.grass][((row * 4 + col) % 3)],
                            color: Colors.green.withValues(alpha: 0.08),
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  }

                  final dog = neighbor.first;
                  final friendship = friendSvc.getFriendship(
                    myDogs.isNotEmpty ? (myDogs.first as dynamic).name as String : '',
                    dog.name,
                  );
                  final isSelected = _selectedDog?.name == dog.name;
                  final isFriend = friendship != null;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedDog = dog);
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
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(dog.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 1),
                          Text(dog.name,
                              style: TextStyle(
                                color: isFriend ? Colors.green : Colors.white54,
                                fontSize: 9,
                                fontWeight: isFriend ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (isFriend)
                            Text(friendship.level.emoji, style: const TextStyle(fontSize: 8)),
                        ]),
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

  Widget _buildDogDetail(
    NeighborhoodDog dog,
    List myDogs,
    DogFriendshipService friendSvc,
  ) {
    final myDogName = myDogs.isNotEmpty ? (myDogs.first as dynamic).name as String : '';
    final friendship = friendSvc.getFriendship(myDogName, dog.name);
    final dogSvc = ref.read(dogServiceProvider);
    final breedDog = dogSvc.lookup(dog.breed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dog.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(dog.breed,
                      style: const TextStyle(color: Colors.amber, fontSize: 13)),
                  Text(dog.personality,
                      style: const TextStyle(color: Colors.white38, fontStyle: FontStyle.italic, fontSize: 12)),
                ]),
              ),
              if (friendship != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(children: [
                    Text(friendship.level.emoji, style: const TextStyle(fontSize: 16)),
                    Text(friendship.level.label,
                        style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                  ]),
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
                onPressed: myDogName.isEmpty ? null : () {
                  friendSvc.befriend(myDogName, dog);
                  ref.read(playerProvider.notifier).awardBonusXp(10);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: bgCard,
                      content: Text('${dog.name} and $myDogName are now friends! +10 XP',
                          style: const TextStyle(color: Colors.green)),
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Visits: ${friendship.visits}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      if (friendship.visitsToNextLevel > 0) ...[
                        const SizedBox(width: 8),
                        Text('${friendship.visitsToNextLevel} to ${_nextLevelLabel(friendship)}',
                            style: const TextStyle(color: Colors.white30, fontSize: 11)),
                      ],
                    ]),
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
                  ]),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: friendship.canVisitToday ? () {
                    final leveled = friendSvc.visit(myDogName, dog.name);
                    if (leveled) {
                      ref.read(playerProvider.notifier).awardBonusXp(5);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: bgCard,
                          content: Text('Visited ${dog.name}! +5 XP',
                              style: const TextStyle(color: Colors.green)),
                        ),
                      );
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: friendship.canVisitToday ? Colors.green : Colors.white12,
                    foregroundColor: friendship.canVisitToday ? Colors.white : Colors.white38,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(friendship.canVisitToday ? 'Visit!' : 'Visited'),
                ),
              ],
            ),
            if (friendship.level.xpBonus > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  Widget _buildFriendsList(DogFriendshipService friendSvc) {
    final friendships = friendSvc.friendships;
    if (friendships.isEmpty) return const SizedBox.shrink();

    // Group by level
    final bestFriends = friendships.where((f) => f.level == FriendshipLevel.bestFriend).toList();
    final friends = friendships.where((f) => f.level == FriendshipLevel.friend).toList();
    final others = friendships.where((f) =>
        f.level == FriendshipLevel.acquaintance || f.level == FriendshipLevel.newNeighbor).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.favorite, color: Colors.green, size: 18),
          SizedBox(width: 6),
          Text('Dog Friends', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 8),
        if (bestFriends.isNotEmpty) _friendshipGroup('Best Friends \u{1F31F}', bestFriends, Colors.amber),
        if (friends.isNotEmpty) _friendshipGroup('Friends \u{1F496}', friends, Colors.green),
        if (others.isNotEmpty) _friendshipGroup('Getting to Know \u{1F44B}', others, Colors.white38),
      ],
    );
  }

  Widget _friendshipGroup(String title, List<DogFriendship> friendships, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: friendships.map((f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(f.neighborEmoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(f.neighborDogName,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              if (f.canVisitToday) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ]),
          )).toList(),
        ),
      ],
    );
  }

  String _nextLevelLabel(DogFriendship f) {
    final next = FriendshipLevel.values.where((l) => l.visitsRequired > f.visits).toList();
    return next.isNotEmpty ? next.first.label : 'Max';
  }

  String _weekNumber() {
    final now = DateTime.now();
    final jan1 = DateTime(now.year, 1, 1);
    return '${((now.difference(jan1).inDays) ~/ 7) + 1}';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Sighting Log View (original MapTab content)
// ═══════════════════════════════════════════════════════════════════════

class _SightingLogView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sightingSvc = ref.read(sightingServiceProvider);
    final dogSvc = ref.read(dogServiceProvider);
    final sightings = sightingSvc.all;
    final grouped = sightingSvc.groupedByDate();

    if (sightings.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.history, size: 80, color: Colors.white24)
                .animate().fadeIn().scale(),
            const SizedBox(height: 16),
            const Text('Sighting Log',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber))
                .animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            const Text(
              'Your sighting history will appear here.\nIdentify dogs to start logging!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ).animate().fadeIn(delay: 200.ms),
          ]),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Stats header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statBubble('Total', '${sightingSvc.totalSightings}', Icons.remove_red_eye),
                    const SizedBox(width: 8),
                    _statBubble('Species', '${sightingSvc.uniqueSpecies}', Icons.category),
                    const SizedBox(width: 8),
                    if (sightingSvc.bestDay != null)
                      _statBubble('Best Day', '${sightingSvc.bestDay!.$2}', Icons.star),
                  ],
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // Grouped sightings by date
        ...grouped.entries.expand((entry) {
          final dateKey = entry.key;
          final daySightings = entry.value;
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_formatDate(dateKey),
                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text('${daySightings.length} sighting${daySightings.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final sighting = daySightings[i];
                  final dog = dogSvc.lookup(sighting.dogName);
                  final count = sightingSvc.sightingCount(sighting.dogName);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (dog != null) {
                          DogDetailSheet.show(context, dog, AudioPlayer(), source: 'sighting_log');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: dog?.rarity.color.withValues(alpha: 0.3) ?? Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 44, height: 44,
                                child: dog != null && dog.imageUrl.isNotEmpty
                                    ? NetworkDogImage(url: dog.imageUrl, height: 44, width: 44, fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        child: const Icon(Icons.help_outline, color: Colors.white24),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sighting.dogName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Row(children: [
                                    Text(_formatTime(sighting.timestamp),
                                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    if (dog != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: dog.rarity.color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(dog.rarity.name,
                                            style: TextStyle(color: dog.rarity.color, fontSize: 9)),
                                      ),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                            if (count > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('\u00D7$count',
                                    style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            const SizedBox(width: 6),
                            Text('${(sighting.confidence * 100).round()}%',
                                style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: daySightings.length,
              ),
            ),
          ];
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _statBubble(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    );
  }

  String _formatDate(String dateKey) {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    if (dateKey == todayKey) return 'Today';
    if (dateKey == yesterdayKey) return 'Yesterday';
    final parts = dateKey.split('-');
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[int.parse(parts[1])]} ${int.parse(parts[2])}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Breed Locations View
// ═══════════════════════════════════════════════════════════════════════

class _BreedLocationsView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BreedLocationsView> createState() => _BreedLocationsViewState();
}

class _BreedLocationsViewState extends ConsumerState<_BreedLocationsView> {
  String? _expandedBreed;

  @override
  Widget build(BuildContext context) {
    final sightingSvc = ref.read(sightingServiceProvider);
    final dogSvc = ref.read(dogServiceProvider);
    final byBreed = sightingSvc.sightingsByBreed();

    if (byBreed.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.map_outlined, size: 80, color: Colors.white24)
                .animate().fadeIn().scale(),
            const SizedBox(height: 16),
            const Text('Breed Locations',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber))
                .animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            const Text(
              'No sightings with GPS data yet.\nEnable location when identifying dogs!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ).animate().fadeIn(delay: 200.ms),
          ]),
        ),
      );
    }

    // Sort breeds by number of sightings (most first)
    final sortedBreeds = byBreed.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: sortedBreeds.length + 1, // +1 for stats header
      itemBuilder: (context, index) {
        if (index == 0) {
          // Stats header
          final totalLocated = byBreed.values.fold<int>(0, (sum, list) => sum + list.length);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _locStat('Breeds', '${byBreed.length}', Icons.pets),
                const SizedBox(width: 8),
                _locStat('Located', '$totalLocated', Icons.place),
              ],
            ).animate().fadeIn(delay: 100.ms),
          );
        }

        final entry = sortedBreeds[index - 1];
        final breedName = entry.key;
        final sightings = entry.value;
        final dog = dogSvc.lookup(breedName);
        final isExpanded = _expandedBreed == breedName;

        // Most recent sighting
        final mostRecent = sightings.reduce(
          (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _expandedBreed = isExpanded ? null : breedName;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isExpanded
                      ? Colors.amber.withValues(alpha: 0.4)
                      : dog?.rarity.color.withValues(alpha: 0.2) ?? Colors.white12,
                ),
              ),
              child: Column(
                children: [
                  // Breed header row
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Breed icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (dog?.rarity.color ?? Colors.white54).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.pets, color: Colors.amber, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Breed name + rarity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(breedName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (dog != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: dog.rarity.color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(dog.rarity.label,
                                          style: TextStyle(
                                              color: dog.rarity.color,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  const SizedBox(width: 6),
                                  Text(_formatRelativeDate(mostRecent.timestamp),
                                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Sighting count badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.place, color: Colors.amber, size: 14),
                            const SizedBox(width: 3),
                            Text('${sightings.length}',
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                  // Expanded sighting locations
                  if (isExpanded) ...[
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    ...sightings.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.my_location,
                              color: Colors.amber.withValues(alpha: 0.5), size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatCoordinates(s.latitude!, s.longitude!),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                          Text(_formatDateTimeFull(s.timestamp),
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    )),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _locStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    );
  }

  String _formatCoordinates(double lat, double lon) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lonDir = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(2)}${String.fromCharCode(0x00B0)}$latDir, '
        '${lon.abs().toStringAsFixed(2)}${String.fromCharCode(0x00B0)}$lonDir';
  }

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatDateTimeFull(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, $h:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Live Map View — Interactive OpenStreetMap with dog sighting pins
// ═══════════════════════════════════════════════════════════════════════

class _LiveMapView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends ConsumerState<_LiveMapView> {
  final MapController _mapController = MapController();
  String? _selectedBreed; // filter to a single breed
  Sighting? _tappedSighting; // currently tapped marker

  @override
  Widget build(BuildContext context) {
    final sightingSvc = ref.watch(sightingServiceProvider);
    final dogSvc = ref.watch(dogServiceProvider);

    // Get all GPS sightings
    final gpsSightings = sightingSvc.all
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    // Apply breed filter
    final filtered = _selectedBreed != null
        ? gpsSightings.where((s) => s.dogName == _selectedBreed).toList()
        : gpsSightings;

    if (gpsSightings.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.satellite_alt, size: 80, color: Colors.white24)
              .animate().fadeIn().scale(),
          const SizedBox(height: 16),
          const Text('Live Sighting Map',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber))
              .animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 8),
          const Text(
            'No GPS sightings yet.\nEnable location when identifying dogs!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ).animate().fadeIn(delay: 200.ms),
        ]),
      );
    }

    // Compute map center from sightings
    final centerLat = filtered.map((s) => s.latitude!).reduce((a, b) => a + b) / filtered.length;
    final centerLon = filtered.map((s) => s.longitude!).reduce((a, b) => a + b) / filtered.length;

    // Unique breeds for filter chips
    final breeds = gpsSightings.map((s) => s.dogName).toSet().toList()..sort();

    // Build markers
    final markers = filtered.map((s) {
      final dog = dogSvc.lookupByCommonName(s.dogName);
      final color = dog != null ? dog.rarity.color : Colors.amber;
      return Marker(
        width: 36,
        height: 36,
        point: LatLng(s.latitude!, s.longitude!),
        child: GestureDetector(
          onTap: () => setState(() => _tappedSighting = s),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 18),
          ),
        ),
      );
    }).toList();

    return Column(
      children: [
        // Breed filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _filterChip('All', null, filtered.length),
              ...breeds.map((b) => _filterChip(
                b,
                b,
                gpsSightings.where((s) => s.dogName == b).length,
              )),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Map
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(centerLat, centerLon),
                    initialZoom: 14.0,
                    minZoom: 3,
                    maxZoom: 18,
                    onTap: (_, __) => setState(() => _tappedSighting = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.dogquest.app',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              // Stats overlay
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: bgDeep.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.pets, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${filtered.length} sighting${filtered.length != 1 ? "s" : ""}',
                      style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    if (_selectedBreed != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _selectedBreed = null),
                        child: const Icon(Icons.close, color: Colors.white54, size: 14),
                      ),
                    ],
                  ]),
                ),
              ),
              // Tapped sighting info card
              if (_tappedSighting != null)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: _SightingInfoCard(
                    sighting: _tappedSighting!,
                    dog: dogSvc.lookupByCommonName(_tappedSighting!.dogName),
                    onClose: () => setState(() => _tappedSighting = null),
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2, end: 0),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? breed, int count) {
    final selected = _selectedBreed == breed;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedBreed = breed);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.amber.withValues(alpha: 0.2) : bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.amber : Colors.white12,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.amber : Colors.white54,
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: selected ? Colors.amber.withValues(alpha: 0.7) : Colors.white30,
                fontSize: 10,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SightingInfoCard extends StatelessWidget {
  final Sighting sighting;
  final dynamic dog; // Dog?
  final VoidCallback onClose;

  const _SightingInfoCard({
    required this.sighting,
    required this.dog,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final rarityColor = dog?.rarity?.color ?? Colors.amber;
    final rarityLabel = dog?.rarity?.label ?? '';
    final confidence = (sighting.confidence * 100).toStringAsFixed(0);

    String timeAgo(DateTime dt) {
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.pets, color: rarityColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      sighting.dogName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (rarityLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: rarityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rarityLabel,
                        style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.access_time, size: 12, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(timeAgo(sighting.timestamp),
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(width: 12),
                  Icon(Icons.verified, size: 12, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text('$confidence%',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: Colors.white38, size: 20),
          ),
        ],
      ),
    );
  }
}
