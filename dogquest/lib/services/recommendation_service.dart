import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../models/dog.dart';
import 'kennel_service.dart';
import 'dog_mastery_service.dart';
import 'dog_service.dart';
import 'player_service.dart';
import 'sighting_service.dart';

// ─── Personal Insight ─────────────────────────────────────────────────────────

class PersonalInsight {
  final String text;
  final IconData icon;
  final Color color;
  final String? actionLabel;

  const PersonalInsight({
    required this.text,
    required this.icon,
    required this.color,
    this.actionLabel,
  });
}

// ─── Recommendation Service ─────────────────────────────────────────────────

class RecommendationService {
  /// Returns dogs the user hasn't collected yet, prioritized by:
  /// 1. Dogs in rarity tiers where the user is close to a milestone
  /// 2. Dogs from habitats where the user has found the most dogs
  /// 3. Common breeds first (easier to find)
  List<Dog> recommendedDogs(
    DogService dogSvc,
    KennelService kennelSvc, {
    int count = 5,
  }) {
    // Get all uncollected dogs
    final uncollected =
        dogSvc.all.where((b) => !kennelSvc.contains(b.name)).toList();

    if (uncollected.isEmpty) return [];

    // Score each dog for prioritization
    final collected = kennelSvc.collectedDogs;
    final habitatCounts = _habitatCounts(collected);
    final rarityProgress = _rarityMilestoneProximity(collected, dogSvc.all);

    uncollected.sort((a, b) {
      final scoreA = _scoreDog(a, habitatCounts, rarityProgress);
      final scoreB = _scoreDog(b, habitatCounts, rarityProgress);
      return scoreB.compareTo(scoreA); // Higher score first
    });

    return uncollected.take(count).toList();
  }

  /// Generates 2-3 contextual insights based on current player state.
  List<PersonalInsight> generateInsights(
    PlayerState player,
    KennelService kennelSvc,
    DogService dogSvc,
    DogMasteryState mastery,
    SightingService sightingSvc,
  ) {
    final insights = <PersonalInsight>[];
    final kennelCount = kennelSvc.count;
    final collected = kennelSvc.collectedDogs;

    // ── Collection milestone proximity ──────────────────────────────────
    const milestones = [5, 10, 20, 50, 100, 200];
    for (final m in milestones) {
      final remaining = m - kennelCount;
      if (remaining > 0 && remaining <= 3) {
        insights.add(PersonalInsight(
          text:
              "You're $remaining species away from the '$m Species' milestone!",
          icon: Icons.emoji_events,
          color: Colors.amber,
          actionLabel: 'View Collection',
        ));
        break;
      }
    }

    // ── Streak insight ──────────────────────────────────────────────────
    if (player.streak > 1 && player.bestStreak > player.streak) {
      final gap = player.bestStreak - player.streak;
      if (gap <= 3) {
        insights.add(PersonalInsight(
          text:
              "Your best streak was ${player.bestStreak} days — you're at ${player.streak} now. Keep going!",
          icon: Icons.local_fire_department,
          color: Colors.deepOrange,
        ));
      }
    } else if (player.streak >= 3) {
      insights.add(PersonalInsight(
        text:
            "${player.streak}-day streak! You're on fire! Keep identifying dogs daily.",
        icon: Icons.local_fire_department,
        color: Colors.deepOrange,
      ));
    }

    // ── Mastery insight ─────────────────────────────────────────────────
    final totalMastered = mastery.totalMastered;
    final totalExpert = mastery.totalExpert;
    if (totalMastered > 0 && totalMastered < 10) {
      final toNext = _nextMasteryMilestone(totalMastered) - totalMastered;
      if (toNext > 0) {
        insights.add(PersonalInsight(
          text:
              "You've mastered $totalMastered dog${totalMastered == 1 ? '' : 's'}. Master $toNext more to reach the next tier!",
          icon: Icons.workspace_premium,
          color: Colors.blue,
          actionLabel: 'View Mastery',
        ));
      }
    } else if (totalExpert > 0 && totalMastered == 0) {
      insights.add(PersonalInsight(
        text:
            "You have $totalExpert dog${totalExpert == 1 ? '' : 's'} at Expert level. Keep sighting them to reach Master!",
        icon: Icons.star,
        color: Colors.blue,
      ));
    }

    // ── Sighting activity ───────────────────────────────────────────────
    final totalSightings = sightingSvc.totalSightings;
    if (totalSightings >= 10 && insights.length < 3) {
      insights.add(PersonalInsight(
        text:
            "You've logged $totalSightings total sightings. Every observation counts!",
        icon: Icons.visibility,
        color: const Color(0xFFD4874E),
      ));
    }

    // ── Habitat insight ─────────────────────────────────────────────────
    if (collected.isNotEmpty && insights.length < 3) {
      final habitatCounts = _habitatCounts(collected);
      if (habitatCounts.isNotEmpty) {
        final topHabitat =
            habitatCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
        if (topHabitat.value >= 3) {
          insights.add(PersonalInsight(
            text:
                "Try looking for dogs in ${topHabitat.key} habitats — you've found ${topHabitat.value} there already!",
            icon: Icons.forest,
            color: const Color(0xFFD4874E),
          ));
        }
      }
    }

    // ── Simulated ranking ───────────────────────────────────────────────
    if (kennelCount >= 15 && insights.length < 3) {
      // Simulated percentile based on collection size
      final percentile = (100 - (kennelCount * 0.6).clamp(5, 85)).round();
      insights.add(PersonalInsight(
        text: "You're in the top $percentile% of collectors!",
        icon: Icons.leaderboard,
        color: Colors.amber,
      ));
    }

    // ── Level progress ──────────────────────────────────────────────────
    if (insights.length < 2 && player.level >= 1) {
      final xpNeeded = player.xpForNextLevel - player.xp;
      insights.add(PersonalInsight(
        text:
            "You need $xpNeeded XP to reach level ${player.level + 1}. Identify more dogs!",
        icon: Icons.arrow_upward,
        color: const Color(0xFFD4874E),
      ));
    }

    // Return at most 3 insights
    return insights.take(3).toList();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Counts how many collected dogs belong to each habitat.
  Map<String, int> _habitatCounts(List<Dog> collected) {
    final counts = <String, int>{};
    for (final dog in collected) {
      final habitat = dog.habitat;
      if (habitat.isNotEmpty && habitat != 'Unknown') {
        counts[habitat] = (counts[habitat] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// For each rarity, how close the user is to a collection milestone.
  /// Returns a map of Rarity -> proximity score (higher = closer to milestone).
  Map<Rarity, double> _rarityMilestoneProximity(
    List<Dog> collected,
    List<Dog> allDogs,
  ) {
    final result = <Rarity, double>{};
    for (final rarity in [Rarity.common, Rarity.uncommon, Rarity.rare, Rarity.legendary]) {
      final totalInRarity =
          allDogs.where((b) => b.rarity == rarity).length;
      final collectedInRarity =
          collected.where((b) => b.rarity == rarity).length;
      if (totalInRarity == 0) continue;

      // Milestones: 25%, 50%, 75%, 100% of that rarity
      const fractions = [0.25, 0.5, 0.75, 1.0];
      double bestProximity = 0;
      for (final f in fractions) {
        final milestone = (totalInRarity * f).ceil();
        final remaining = milestone - collectedInRarity;
        if (remaining > 0 && remaining <= 5) {
          // Closer to milestone = higher score
          bestProximity = (6 - remaining) / 5.0;
          break;
        }
      }
      result[rarity] = bestProximity;
    }
    return result;
  }

  /// Score a dog for recommendation priority.
  double _scoreDog(
    Dog dog,
    Map<String, int> habitatCounts,
    Map<Rarity, double> rarityProgress,
  ) {
    double score = 0;

    // Priority 1: Rarity milestone proximity (0-2 points)
    score += (rarityProgress[dog.rarity] ?? 0) * 2.0;

    // Priority 2: Habitat familiarity (0-1 points)
    final habitatCount = habitatCounts[dog.habitat] ?? 0;
    score += (habitatCount / 20.0).clamp(0.0, 1.0);

    // Priority 3: Easier breeds first (common > uncommon > rare > legendary)
    switch (dog.rarity) {
      case Rarity.common:
        score += 0.4;
        break;
      case Rarity.uncommon:
        score += 0.3;
        break;
      case Rarity.rare:
        score += 0.2;
        break;
      case Rarity.legendary:
        score += 0.1;
        break;
      case Rarity.unknown:
        break;
    }

    return score;
  }

  /// Next mastery milestone given current mastered count.
  int _nextMasteryMilestone(int current) {
    const milestones = [3, 5, 10, 15, 25, 50];
    for (final m in milestones) {
      if (current < m) return m;
    }
    return current + 10;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return RecommendationService();
});
