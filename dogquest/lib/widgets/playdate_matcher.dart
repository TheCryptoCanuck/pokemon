import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog_friendship.dart';
import 'package:dogquest/services/dog_friendship_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/location_service.dart';
import 'package:dogquest/services/playdate_service.dart';

/// Playdate match result with compatibility score.
class PlaydateMatch {
  final NeighborhoodDog neighbor;
  final String breedName;
  final double compatibility; // 0.0 - 1.0
  final List<String> reasons;
  final String matchEmoji;

  const PlaydateMatch({
    required this.neighbor,
    required this.breedName,
    required this.compatibility,
    required this.reasons,
    required this.matchEmoji,
  });
}

/// Suggests compatible neighborhood dogs for playdates based on size, energy, temperament.
/// When authenticated with Supabase, also shows nearby upcoming playdates from the backend.
class PlaydateMatcher extends ConsumerStatefulWidget {
  final String? userBreedFilter; // optional: filter by user's dog breed

  const PlaydateMatcher({super.key, this.userBreedFilter});

  @override
  ConsumerState<PlaydateMatcher> createState() => _PlaydateMatcherState();
}

class _PlaydateMatcherState extends ConsumerState<PlaydateMatcher> {
  List<PlaydateRemote> _nearbyPlaydates = [];
  bool _loadingRemote = false;
  String? _remoteError;

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaydates();
  }

  Future<void> _loadNearbyPlaydates() async {
    final svc = ref.read(playdateServiceProvider);
    if (svc == null) return;

    setState(() {
      _loadingRemote = true;
      _remoteError = null;
    });

    try {
      final locSvc = ref.read(locationServiceProvider);
      final pos = await locSvc.getLocation();
      if (pos == null) {
        setState(() {
          _remoteError = 'Location unavailable';
          _loadingRemote = false;
        });
        return;
      }

      final playdates = await svc.getUpcomingNearby(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) {
        setState(() {
          _nearbyPlaydates = playdates;
          _loadingRemote = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _remoteError = 'Could not load playdates';
          _loadingRemote = false;
        });
      }
    }
  }

  List<PlaydateMatch> _computeMatches(
    List<NeighborhoodDog> neighbors,
    DogService dogSvc,
    String? filterBreed,
  ) {
    final filterDog =
        filterBreed != null ? dogSvc.lookupByCommonName(filterBreed) : null;
    final matches = <PlaydateMatch>[];

    for (final neighbor in neighbors) {
      final breedDog = dogSvc.lookupByCommonName(neighbor.breed);
      if (breedDog == null) continue;

      double score = 0.5; // base compatibility
      final reasons = <String>[];

      if (filterDog != null) {
        // Size compatibility: same or adjacent size = good
        final sizeOrder = ['small', 'medium', 'large', 'giant'];
        final userIdx = sizeOrder.indexOf(filterDog.sizeCategory);
        final neighborIdx = sizeOrder.indexOf(breedDog.sizeCategory);
        final sizeDiff = (userIdx - neighborIdx).abs();
        if (sizeDiff == 0) {
          score += 0.2;
          reasons.add('Same size!');
        } else if (sizeDiff == 1) {
          score += 0.1;
          reasons.add('Similar size');
        } else {
          score -= 0.1;
        }

        // Energy level compatibility
        final energyOrder = ['low', 'moderate', 'high', 'very high'];
        final userEnergy = energyOrder.indexOf(filterDog.exerciseNeeds);
        final neighborEnergy = energyOrder.indexOf(breedDog.exerciseNeeds);
        final energyDiff = (userEnergy - neighborEnergy).abs();
        if (energyDiff == 0) {
          score += 0.15;
          reasons.add('Matching energy!');
        } else if (energyDiff == 1) {
          score += 0.05;
          reasons.add('Compatible energy');
        }

        // Temperament overlap
        final commonTraits = filterDog.temperamentTraits
            .where((t) => breedDog.temperamentTraits.contains(t))
            .toList();
        if (commonTraits.isNotEmpty) {
          score += 0.1 * min(commonTraits.length, 3);
          reasons.add('Both ${commonTraits.first.toLowerCase()}');
        }
      } else {
        // No filter -- use personality text as a fun reason
        reasons.add(neighbor.personality);
        score = 0.5 + Random(neighbor.name.hashCode).nextDouble() * 0.4;
      }

      score = score.clamp(0.0, 1.0);

      final emoji = score > 0.8
          ? '\u{1F525}' // fire
          : score > 0.6
              ? '\u{2B50}' // star
              : score > 0.4
                  ? '\u{1F43E}' // paw
                  : '\u{1F914}'; // thinking

      matches.add(
        PlaydateMatch(
          neighbor: neighbor,
          breedName: breedDog.name,
          compatibility: score,
          reasons: reasons,
          matchEmoji: emoji,
        ),
      );
    }

    matches.sort((a, b) => b.compatibility.compareTo(a.compatibility));
    return matches;
  }

  Future<void> _showCreatePlaydateDialog() async {
    final svc = ref.read(playdateServiceProvider);
    if (svc == null) return;

    final nameController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    int maxDogs = 5;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: bgCard,
              title: const Text(
                'Create Playdate',
                style: TextStyle(color: textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location name
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Location name',
                        labelStyle: const TextStyle(color: textSecondary),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Date picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Date: ${DateFormat.yMMMd().format(selectedDate)}',
                        style:
                            const TextStyle(color: textPrimary, fontSize: 14),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: accent,
                        size: 20,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    // Time picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Time: ${selectedTime.format(ctx)}',
                        style:
                            const TextStyle(color: textPrimary, fontSize: 14),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: accent,
                        size: 20,
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Max dogs slider
                    Text(
                      'Max dogs: $maxDogs',
                      style:
                          const TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    Slider(
                      value: maxDogs.toDouble(),
                      min: 2,
                      max: 20,
                      divisions: 18,
                      activeColor: accent,
                      inactiveColor: textSecondary.withValues(alpha: 0.2),
                      label: '$maxDogs',
                      onChanged: (v) {
                        setDialogState(() => maxDogs = v.round());
                      },
                    ),
                    const SizedBox(height: 8),
                    // Description
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: textPrimary),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        labelStyle: const TextStyle(color: textSecondary),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || nameController.text.trim().isEmpty) return;

    // Get current location for the playdate
    final locSvc = ref.read(locationServiceProvider);
    final pos = await locSvc.getLocation();
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location unavailable')),
        );
      }
      return;
    }

    final scheduledAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    String? organizerDogId;
    // MyDogService uses local Hive -- no remote dog_id available yet
    // organizerDogId stays null until Supabase dog_profiles are linked

    final created = await svc.createPlaydate(
      locationName: nameController.text.trim(),
      lat: pos.latitude,
      lon: pos.longitude,
      scheduledAt: scheduledAt,
      maxDogs: maxDogs,
      description: descController.text.trim().isEmpty
          ? null
          : descController.text.trim(),
      organizerDogId: organizerDogId,
    );

    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playdate created!')),
      );
      _loadNearbyPlaydates();
    }
  }

  Future<void> _handleRsvp(PlaydateRemote playdate) async {
    final svc = ref.read(playdateServiceProvider);
    if (svc == null) return;

    // For now pass null dog_id since local MyDogService doesn't have Supabase IDs
    final success = await svc.rsvp(playdate.id, null);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RSVP confirmed!')),
      );
      _loadNearbyPlaydates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendshipSvc = ref.watch(dogFriendshipServiceProvider);
    final dogSvc = ref.watch(dogServiceProvider);
    final playdateSvc = ref.watch(playdateServiceProvider);
    final neighbors = friendshipSvc.getNeighborhoodDogs();
    final matches = _computeMatches(neighbors, dogSvc, widget.userBreedFilter);

    final isOnline = playdateSvc != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header with Create button ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.pets, color: accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Playdate Matches',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (isOnline)
                GestureDetector(
                  onTap: _showCreatePlaydateDialog,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: accent, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Create',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!isOnline)
                Text(
                  '${matches.length} dogs',
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
            ],
          ),
        ),

        // ── Remote playdates section ─────────────────────────────────────
        if (isOnline) ...[
          if (_loadingRemote)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: accent),
                ),
              ),
            )
          else if (_remoteError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _remoteError!,
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
            )
          else if (_nearbyPlaydates.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                'Nearby Playdates (${_nearbyPlaydates.length})',
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _nearbyPlaydates.length,
                itemBuilder: (context, index) {
                  final pd = _nearbyPlaydates[index];
                  return _RemotePlaydateCard(
                    playdate: pd,
                    onRsvp: () => _handleRsvp(pd),
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: index * 80))
                      .slideX(begin: 0.1, end: 0);
                },
              ),
            ),
            const SizedBox(height: 8),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'No upcoming playdates nearby -- create one!',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ),
        ],

        // ── Local compatibility matches (offline fallback) ───────────────
        if (matches.isEmpty && !isOnline)
          Container(
            padding: const EdgeInsets.all(20),
            child: const Center(
              child: Text(
                'No neighborhood dogs available for playdates',
                style: TextStyle(color: textSecondary),
              ),
            ),
          )
        else if (matches.isNotEmpty) ...[
          if (isOnline)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                'Local Matches (${matches.length})',
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                return _PlaydateCard(match: match)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: index * 80))
                    .slideX(begin: 0.1, end: 0);
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Remote Playdate Card ────────────────────────────────────────────────────

class _RemotePlaydateCard extends StatelessWidget {
  final PlaydateRemote playdate;
  final VoidCallback onRsvp;

  const _RemotePlaydateCard({required this.playdate, required this.onRsvp});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.MMMd().format(playdate.scheduledAt);
    final timeStr = DateFormat.jm().format(playdate.scheduledAt);
    final distStr = playdate.distanceMiles != null
        ? '${playdate.distanceMiles!.toStringAsFixed(1)} mi'
        : '';
    final spotsLeft = playdate.maxDogs - playdate.rsvpCount;

    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 10, bottom: 4),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dog name + breed
          Text(
            playdate.organizerDogName ?? playdate.organizerUsername,
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (playdate.organizerDogBreed != null)
            Text(
              playdate.organizerDogBreed!,
              style: const TextStyle(color: textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          // Location
          Row(
            children: [
              const Icon(Icons.location_on, color: accent, size: 12),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  playdate.locationName,
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Date + time
          Row(
            children: [
              const Icon(Icons.access_time, color: accent, size: 12),
              const SizedBox(width: 3),
              Text(
                '$dateStr $timeStr',
                style: const TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          // RSVP count + distance + RSVP button
          Row(
            children: [
              Text(
                '${playdate.rsvpCount}/${playdate.maxDogs}',
                style: TextStyle(
                  color: spotsLeft > 0 ? accent : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (distStr.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  distStr,
                  style: const TextStyle(color: textSecondary, fontSize: 10),
                ),
              ],
              const Spacer(),
              if (spotsLeft > 0)
                GestureDetector(
                  onTap: onRsvp,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'RSVP',
                      style: TextStyle(
                        color: bgDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                const Text(
                  'Full',
                  style: TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Local Playdate Card ─────────────────────────────────────────────────────

class _PlaydateCard extends StatelessWidget {
  final PlaydateMatch match;
  const _PlaydateCard({required this.match});

  Color get _compatColor {
    if (match.compatibility > 0.8) return Colors.green;
    if (match.compatibility > 0.6) return Colors.amber;
    if (match.compatibility > 0.4) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10, bottom: 4),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _compatColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji + compatibility
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(match.neighbor.emoji, style: const TextStyle(fontSize: 28)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _compatColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(match.compatibility * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: _compatColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            match.neighbor.name,
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            match.breedName,
            style: const TextStyle(color: textSecondary, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // Top reason
          if (match.reasons.isNotEmpty)
            Text(
              '${match.matchEmoji} ${match.reasons.first}',
              style: const TextStyle(color: accent, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
