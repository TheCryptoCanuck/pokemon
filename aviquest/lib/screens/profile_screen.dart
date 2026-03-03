import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../helpers/game_helpers.dart';
import '../models/bird.dart';
import '../services/aviary_service.dart';
import '../services/bird_family_service.dart';
import '../services/bird_service.dart';
import '../services/player_service.dart';
import '../services/seasonal_event_service.dart';
import '../services/sighting_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final aviarySvc = ref.read(aviaryServiceProvider);
    final birdSvc = ref.read(birdServiceProvider);
    final familySvc = ref.read(birdFamilyServiceProvider);
    final sightingSvc = ref.read(sightingServiceProvider);
    final seasonalSvc = ref.read(seasonalEventServiceProvider);
    final nextLevelXp = playerState.xpForNextLevel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Colors.amber, Color(0xFF4CAF50)]),
              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)],
            ),
            child: const Center(child: Text('🦅', style: TextStyle(fontSize: 48))),
          ).animate().fadeIn().scale(),
          const SizedBox(height: 16),
          Text(playerState.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber))
              .animate().fadeIn(delay: 100.ms),
          Text('Level ${playerState.level}', style: const TextStyle(fontSize: 16, color: Colors.white54)),
          const SizedBox(height: 20),

          // XP Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('XP Progress', style: TextStyle(color: Colors.white70)),
                Text('${playerState.xp} / $nextLevelXp', style: const TextStyle(color: Colors.amber)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: playerState.xpProgress,
                  minHeight: 12,
                  backgroundColor: bgCard,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 20),

          // Stats row 1
          Row(
            children: [
              _statCard('🔥', '${playerState.streak}', 'Day Streak'),
              const SizedBox(width: 12),
              _statCard('🐦', '${aviarySvc.count}', 'Species'),
              const SizedBox(width: 12),
              _statCard('🏆', '${playerState.unlockedAchievements.length}', 'Badges'),
            ],
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),

          // Stats row 2
          Row(
            children: [
              _statCard('👁️', '${sightingSvc.totalSightings}', 'Sightings'),
              const SizedBox(width: 12),
              _statCard('📝', '${playerState.quizzesCompleted}', 'Quizzes'),
              const SizedBox(width: 12),
              _statCard('🥇', '${familySvc.completedFamilies}', 'Families'),
            ],
          ).animate().fadeIn(delay: 250.ms),

          // Best streak and streak savers
          if (playerState.bestStreak > 1 || playerState.streakSavers > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (playerState.bestStreak > 1)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Text('🏅', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text('Best: ${playerState.bestStreak} days',
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                  ),
                if (playerState.bestStreak > 1 && playerState.streakSavers > 0)
                  const SizedBox(width: 12),
                if (playerState.streakSavers > 0)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Text('🛡️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text('${playerState.streakSavers} streak saver${playerState.streakSavers > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                  ),
              ],
            ).animate().fadeIn(delay: 270.ms),
          ],
          const SizedBox(height: 16),

          // Active XP Bonuses summary
          ..._buildActiveBonuses(playerState, seasonalSvc),

          const SizedBox(height: 16),

          // Collection progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Collection Progress',
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                Row(children: [
                  Text('${aviarySvc.count}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                  Text(' / ${birdSvc.all.length} species',
                      style: const TextStyle(color: Colors.white54)),
                  const Spacer(),
                  Text('${(aviarySvc.count / birdSvc.all.length * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: birdSvc.all.isEmpty ? 0 : aviarySvc.count / birdSvc.all.length,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final r in [Rarity.common, Rarity.uncommon, Rarity.rare, Rarity.legendary])
                      _rarityCount(r, aviarySvc, birdSvc),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 350.ms),

          const SizedBox(height: 20),

          // Next achievements to unlock
          ..._buildNextAchievements(playerState, aviarySvc, birdSvc),

          // Achievements
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Achievements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${playerState.unlockedAchievements.length} / ${achievements.length} unlocked',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: achievements.entries.map((e) {
              final unlocked = playerState.unlockedAchievements.contains(e.key);
              return Tooltip(
                message: unlocked ? '${e.value.$2}: ${e.value.$3}' : e.value.$3,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: unlocked ? Colors.amber.withOpacity(0.15) : bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: unlocked ? Colors.amber : Colors.white12),
                  ),
                  child: Center(
                    child: Text(
                      unlocked ? e.value.$1 : '🔒',
                      style: TextStyle(fontSize: 28, color: unlocked ? null : Colors.white24),
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 24),

          // Eco Impact
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Text('🌍', style: TextStyle(fontSize: 32)),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Eco Impact', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text('Your sightings help scientists track bird populations worldwide.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
            ]),
          ).animate().fadeIn(delay: 450.ms),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Build active XP bonus indicators (streak, seasonal event).
  List<Widget> _buildActiveBonuses(PlayerState playerState, SeasonalEventService seasonalSvc) {
    final widgets = <Widget>[];
    final event = seasonalSvc.primaryEvent;

    // Streak bonus
    if (playerState.streakXpMultiplier > 1.0) {
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.orange.withOpacity(0.15),
              Colors.red.withOpacity(0.08),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Streak Bonus Active',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('+${((playerState.streakXpMultiplier - 1) * 100).round()}% XP on all birds',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${playerState.streakXpMultiplier}x',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
          ]),
        ).animate().fadeIn(delay: 300.ms),
      );
      widgets.add(const SizedBox(height: 8));
    }

    // Seasonal event bonus
    if (event != null) {
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              event.themeColor.withOpacity(0.15),
              event.themeColor.withOpacity(0.05),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: event.themeColor.withOpacity(0.5)),
          ),
          child: Row(children: [
            Text(event.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.name,
                    style: TextStyle(color: event.themeColor, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${event.daysRemaining} days remaining',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: event.themeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${event.xpMultiplier}x XP',
                  style: TextStyle(color: event.themeColor, fontWeight: FontWeight.bold)),
            ),
          ]),
        ).animate().fadeIn(delay: 320.ms),
      );
      widgets.add(const SizedBox(height: 8));
    }

    return widgets;
  }

  /// Build "next achievements" section showing closest unlockable achievements.
  List<Widget> _buildNextAchievements(PlayerState playerState, AviaryService aviarySvc, BirdService birdSvc) {
    final unlocked = playerState.unlockedAchievements;
    final hints = <_AchievementHint>[];

    // Collection milestones
    final count = aviarySvc.count;
    final milestones = [
      (5, 'five_species'), (10, 'ten_species'), (20, 'twenty_species'),
      (50, 'fifty_species'), (100, 'hundred_species'), (200, 'two_hundred_species'),
    ];
    for (final (target, key) in milestones) {
      if (!unlocked.contains(key) && count > 0) {
        final remaining = target - count;
        if (remaining > 0 && remaining <= target) {
          hints.add(_AchievementHint(
            key: key,
            progress: count / target,
            hint: '$remaining more species to go',
          ));
        }
        break; // Only show next milestone
      }
    }

    // Rarity collection progress
    final collectedBirds = aviarySvc.collectedBirds;
    final rareCount = collectedBirds.where((b) => b.rarity == Rarity.rare).length;
    if (!unlocked.contains('five_rare') && rareCount > 0) {
      hints.add(_AchievementHint(
        key: 'five_rare',
        progress: rareCount / 5,
        hint: '${5 - rareCount} more rare birds needed',
      ));
    }
    final legendaryCount = collectedBirds.where((b) => b.rarity == Rarity.legendary).length;
    if (!unlocked.contains('five_legendary') && legendaryCount > 0) {
      hints.add(_AchievementHint(
        key: 'five_legendary',
        progress: legendaryCount / 5,
        hint: '${5 - legendaryCount} more legendary birds needed',
      ));
    }

    // Streak milestones
    final streak = playerState.streak;
    final streakMilestones = [(3, 'streak_3'), (7, 'streak_7'), (30, 'streak_30')];
    for (final (target, key) in streakMilestones) {
      if (!unlocked.contains(key) && streak > 0) {
        hints.add(_AchievementHint(
          key: key,
          progress: streak / target,
          hint: '${target - streak} more days for streak',
        ));
        break;
      }
    }

    // Quiz milestones
    final quizzes = playerState.quizzesCompleted;
    if (!unlocked.contains('ten_quizzes') && quizzes > 0 && quizzes < 10) {
      hints.add(_AchievementHint(
        key: 'ten_quizzes',
        progress: quizzes / 10,
        hint: '${10 - quizzes} more quizzes to complete',
      ));
    }

    if (hints.isEmpty) return [];

    // Sort by progress descending (closest to completion first)
    hints.sort((a, b) => b.progress.compareTo(a.progress));
    final displayHints = hints.take(3).toList();

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Text('🎯', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Next Achievements',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            ...displayHints.map((hint) {
              final achievement = achievements[hint.key];
              if (achievement == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Text(achievement.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(achievement.$2,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: hint.progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            hint.progress >= 0.75 ? Colors.amber : Colors.white38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(hint.hint,
                          style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text('${(hint.progress * 100).round()}%',
                      style: TextStyle(
                        color: hint.progress >= 0.75 ? Colors.amber : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      )),
                ]),
              );
            }),
          ],
        ),
      ).animate().fadeIn(delay: 370.ms),
      const SizedBox(height: 20),
    ];
  }

  Widget _statCard(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _rarityCount(Rarity rarity, AviaryService aviarySvc, BirdService birdSvc) {
    final collected = aviarySvc.collectedBirds
        .where((b) => b.rarity == rarity)
        .length;
    final total = birdSvc.all.where((b) => b.rarity == rarity).length;
    return Column(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: rarity.color, shape: BoxShape.circle),
      ),
      const SizedBox(height: 2),
      Text('$collected/$total',
          style: TextStyle(color: rarity.color, fontSize: 11, fontWeight: FontWeight.bold)),
      Text(rarity.name, style: const TextStyle(color: Colors.white38, fontSize: 9)),
    ]);
  }
}

class _AchievementHint {
  final String key;
  final double progress;
  final String hint;

  const _AchievementHint({required this.key, required this.progress, required this.hint});
}
