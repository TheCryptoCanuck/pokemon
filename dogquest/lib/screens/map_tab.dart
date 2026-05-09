import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:latlong2/latlong.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/models/dog_friendship.dart';
import 'package:dogquest/services/dog_friendship_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/my_dog_service.dart';
import 'package:dogquest/services/sighting_service.dart';
import 'package:dogquest/widgets/dog_detail_sheet.dart';
import 'package:dogquest/widgets/network_dog_image.dart';
import 'package:dogquest/widgets/map/tab_button.dart';
import 'package:dogquest/widgets/map/friendship_stats_bar.dart';
import 'package:dogquest/widgets/map/neighborhood_grid.dart';
import 'package:dogquest/widgets/map/dog_detail_card.dart';
import 'package:dogquest/widgets/map/dog_selection_prompt.dart';
import 'package:dogquest/widgets/map/friends_list.dart';
import 'package:dogquest/widgets/map/neighborhood_empty_state.dart';
import 'package:dogquest/widgets/map/sighting_stat_bubble.dart';
import 'package:dogquest/widgets/map/breed_location_stat.dart';
import 'package:dogquest/widgets/map/live_map_filter_chip.dart';

class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  int _selectedTab =
      0; // 0=Neighborhood, 1=Sighting Log, 2=Breed Map, 3=Live Map

  @override
  Widget build(BuildContext context) {
    final localSightings =
        Hive.box('hound_prefs').get('localSightingsCount', defaultValue: 0)
            as int;
    if (localSightings == 0) return const _FeaturedBreedsView();

    return Column(
      children: [
        // Toggle bar
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              MapTabButton(
                label: 'Hood',
                icon: Icons.location_city,
                tabIndex: 0,
                selectedTab: _selectedTab,
                onTap: (tabIndex) => setState(() => _selectedTab = tabIndex),
              ),
              const SizedBox(width: 6),
              MapTabButton(
                label: 'Log',
                icon: Icons.history,
                tabIndex: 1,
                selectedTab: _selectedTab,
                onTap: (tabIndex) => setState(() => _selectedTab = tabIndex),
              ),
              const SizedBox(width: 6),
              MapTabButton(
                label: 'Breeds',
                icon: Icons.map_outlined,
                tabIndex: 2,
                selectedTab: _selectedTab,
                onTap: (tabIndex) => setState(() => _selectedTab = tabIndex),
              ),
              const SizedBox(width: 6),
              MapTabButton(
                label: 'Live Map',
                icon: Icons.satellite_alt,
                tabIndex: 3,
                selectedTab: _selectedTab,
                onTap: (tabIndex) => setState(() => _selectedTab = tabIndex),
              ),
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
      return const NeighborhoodEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Friendship stats bar
          FriendshipStatsBar(friendSvc: friendSvc),
          const SizedBox(height: 12),

          // Neighborhood grid
          NeighborhoodGrid(
            neighborDogs: neighborDogs,
            myDogs: myDogs,
            friendSvc: friendSvc,
            selectedDog: _selectedDog,
            onDogSelected: (dog) => setState(() => _selectedDog = dog),
          ),
          const SizedBox(height: 16),

          // Selected dog detail or instructions
          if (_selectedDog != null)
            DogDetailCard(
              dog: _selectedDog!,
              myDogs: myDogs,
              friendSvc: friendSvc,
              onFriendshipChanged: () => setState(() {}),
            )
          else
            const DogSelectionPrompt(),

          const SizedBox(height: 16),

          // Friends list
          FriendsList(friendSvc: friendSvc),
          const SizedBox(height: 32),
        ],
      ),
    );
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, size: 80, color: Colors.white24)
                  .animate()
                  .fadeIn()
                  .scale(),
              const SizedBox(height: 16),
              const Text(
                'Sighting Log',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 8),
              const Text(
                'Your sighting history will appear here.\nIdentify dogs to start logging!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
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
                    SightingStatBubble(
                      label: 'Total',
                      value: '${sightingSvc.totalSightings}',
                      icon: Icons.remove_red_eye,
                    ),
                    const SizedBox(width: 8),
                    SightingStatBubble(
                      label: 'Species',
                      value: '${sightingSvc.uniqueSpecies}',
                      icon: Icons.category,
                    ),
                    const SizedBox(width: 8),
                    if (sightingSvc.bestDay != null)
                      SightingStatBubble(
                        label: 'Best Day',
                        value: '${sightingSvc.bestDay!.$2}',
                        icon: Icons.star,
                      ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatDate(dateKey),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${daySightings.length} sighting${daySightings.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (dog != null) {
                          DogDetailSheet.show(
                            context,
                            dog,
                            AudioPlayer(),
                            source: 'sighting_log',
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: dog?.rarity.color.withValues(alpha: 0.3) ??
                                Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: dog != null && dog.imageUrl.isNotEmpty
                                    ? NetworkDogImage(
                                        url: dog.imageUrl,
                                        height: 44,
                                        width: 44,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.white
                                            .withValues(alpha: 0.05),
                                        child: const Icon(
                                          Icons.help_outline,
                                          color: Colors.white24,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sighting.dogName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        _formatTime(sighting.timestamp),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (dog != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: dog.rarity.color
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            dog.rarity.name,
                                            style: TextStyle(
                                              color: dog.rarity.color,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (count > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.deepPurple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '\u00D7$count',
                                  style: const TextStyle(
                                    color: Colors.deepPurpleAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              '${(sighting.confidence * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
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

  String _formatDate(String dateKey) {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    if (dateKey == todayKey) return 'Today';
    if (dateKey == yesterdayKey) return 'Yesterday';
    final parts = dateKey.split('-');
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
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
  ConsumerState<_BreedLocationsView> createState() =>
      _BreedLocationsViewState();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 80, color: Colors.white24)
                  .animate()
                  .fadeIn()
                  .scale(),
              const SizedBox(height: 16),
              const Text(
                'Breed Locations',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 8),
              const Text(
                'No sightings with GPS data yet.\nEnable location when identifying dogs!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
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
          final totalLocated =
              byBreed.values.fold<int>(0, (sum, list) => sum + list.length);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                BreedLocationStat(
                  label: 'Breeds',
                  value: '${byBreed.length}',
                  icon: Icons.pets,
                ),
                const SizedBox(width: 8),
                BreedLocationStat(
                  label: 'Located',
                  value: '$totalLocated',
                  icon: Icons.place,
                ),
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
                      : dog?.rarity.color.withValues(alpha: 0.2) ??
                          Colors.white12,
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
                            color: (dog?.rarity.color ?? Colors.white54)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child:
                                Icon(Icons.pets, color: Colors.amber, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Breed name + rarity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                breedName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (dog != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: dog.rarity.color
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        dog.rarity.label,
                                        style: TextStyle(
                                          color: dog.rarity.color,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatRelativeDate(mostRecent.timestamp),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Sighting count badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${sightings.length}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
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
                    ...sightings.map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              color: Colors.amber.withValues(alpha: 0.5),
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatCoordinates(s.latitude!, s.longitude!),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              _formatDateTimeFull(s.timestamp),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatDateTimeFull(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.satellite_alt, size: 80, color: Colors.white24)
                .animate()
                .fadeIn()
                .scale(),
            const SizedBox(height: 16),
            const Text(
              'Live Sighting Map',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            const Text(
              'No GPS sightings yet.\nEnable location when identifying dogs!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      );
    }

    // Compute map center from sightings
    final centerLat = filtered.map((s) => s.latitude!).reduce((a, b) => a + b) /
        filtered.length;
    final centerLon =
        filtered.map((s) => s.longitude!).reduce((a, b) => a + b) /
            filtered.length;

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
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
              ],
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
              LiveMapFilterChip(
                label: 'All',
                breed: null,
                count: filtered.length,
                selected: _selectedBreed == null,
                onTap: (breed) => setState(() => _selectedBreed = breed),
              ),
              ...breeds.map(
                (b) => LiveMapFilterChip(
                  label: b,
                  breed: b,
                  count: gpsSightings.where((s) => s.dogName == b).length,
                  selected: _selectedBreed == b,
                  onTap: (breed) => setState(() => _selectedBreed = breed),
                ),
              ),
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
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.hound.app',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: bgDeep.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pets, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${filtered.length} sighting${filtered.length != 1 ? "s" : ""}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedBreed != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _selectedBreed = null),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white54,
                            size: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
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
                  )
                      .animate()
                      .fadeIn(duration: 200.ms)
                      .slideY(begin: 0.2, end: 0),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Featured Breeds — shown on Discover tab until first scan is completed
// ═══════════════════════════════════════════════════════════════════════

class _FeaturedBreedsView extends ConsumerWidget {
  const _FeaturedBreedsView();

  static const _featuredBreeds = [
    'Golden Retriever',
    'German Shepherd',
    'Labrador Retriever',
    'French Bulldog',
    'Bulldog',
    'Poodle',
    'Beagle',
    'Rottweiler',
    'Yorkshire Terrier',
    'Dachshund',
    'Boxer',
    'Shih Tzu',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dogSvc = ref.read(dogServiceProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discover Breeds',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 4),
                const Text(
                  'Identify your first dog to unlock your Sighting Log.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ).animate().fadeIn(delay: 80.ms),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final name = _featuredBreeds[i];
                final dog = dogSvc.lookup(name);
                return GestureDetector(
                  onTap: () => context.push(
                    '/breed/${Uri.encodeComponent(name)}',
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dog?.rarity.color.withValues(alpha: 0.3) ??
                            Colors.white12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                            child: dog != null && dog.imageUrl.isNotEmpty
                                ? NetworkDogImage(
                                    url: dog.imageUrl,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    child: const Center(
                                      child: Text(
                                        '🐶',
                                        style: TextStyle(fontSize: 48),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (dog != null) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: dog.rarity.color
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    dog.rarity.label,
                                    style: TextStyle(
                                      color: dog.rarity.color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: 60 * i));
              },
              childCount: _featuredBreeds.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
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
    final Dog? typedDog = dog as Dog?;
    final rarityColor = typedDog?.rarity.color ?? Colors.amber;
    final rarityLabel = typedDog?.rarity.label ?? '';
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
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
        ],
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
                Row(
                  children: [
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rarityLabel,
                          style: TextStyle(
                            color: rarityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 12, color: Colors.white38,),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo(sighting.timestamp),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.verified, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      '$confidence%',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
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
