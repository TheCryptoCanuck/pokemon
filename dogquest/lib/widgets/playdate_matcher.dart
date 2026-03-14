import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../models/dog_friendship.dart';
import '../services/dog_friendship_service.dart';
import '../services/dog_service.dart';

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
class PlaydateMatcher extends ConsumerWidget {
  final String? userBreedFilter; // optional: filter by user's dog breed

  const PlaydateMatcher({super.key, this.userBreedFilter});

  List<PlaydateMatch> _computeMatches(
    List<NeighborhoodDog> neighbors,
    DogService dogSvc,
    String? filterBreed,
  ) {
    final filterDog = filterBreed != null ? dogSvc.lookupByCommonName(filterBreed) : null;
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
        // No filter — use personality text as a fun reason
        reasons.add(neighbor.personality);
        score = 0.5 + Random(neighbor.name.hashCode).nextDouble() * 0.4;
      }

      score = score.clamp(0.0, 1.0);

      final emoji = score > 0.8 ? '\u{1F525}' // fire
          : score > 0.6 ? '\u{2B50}' // star
          : score > 0.4 ? '\u{1F43E}' // paw
          : '\u{1F914}'; // thinking

      matches.add(PlaydateMatch(
        neighbor: neighbor,
        breedName: breedDog.name,
        compatibility: score,
        reasons: reasons,
        matchEmoji: emoji,
      ));
    }

    matches.sort((a, b) => b.compatibility.compareTo(a.compatibility));
    return matches;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendshipSvc = ref.watch(dogFriendshipServiceProvider);
    final dogSvc = ref.watch(dogServiceProvider);
    final neighbors = friendshipSvc.getNeighborhoodDogs();
    final matches = _computeMatches(neighbors, dogSvc, userBreedFilter);

    if (matches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No neighborhood dogs available for playdates',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.pets, color: accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Playdate Matches',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '${matches.length} dogs',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
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
    );
  }
}

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
                  style: TextStyle(color: _compatColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            match.neighbor.name,
            style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            match.breedName,
            style: TextStyle(color: textSecondary, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // Top reason
          if (match.reasons.isNotEmpty)
            Text(
              '${match.matchEmoji} ${match.reasons.first}',
              style: TextStyle(color: accent, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
