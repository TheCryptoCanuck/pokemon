import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../helpers/game_helpers.dart';
import '../services/aviary_service.dart';
import '../services/bird_family_service.dart';
import '../services/bird_service.dart';
import '../services/player_service.dart';
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
          const SizedBox(height: 16),

          // Streak XP multiplier
          if (playerState.streakXpMultiplier > 1.0)
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
                message: unlocked ? '${e.value.$2}: ${e.value.$3}' : '???',
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
    final collected = aviarySvc.all
        .map((name) => birdSvc.lookup(name))
        .where((b) => b != null && b.rarity == rarity)
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
