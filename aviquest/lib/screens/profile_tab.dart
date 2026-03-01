import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../helpers/game_helpers.dart';

class ProfileTab extends StatelessWidget {
  final int level;
  final int xp;
  final int streak;
  final int collectedCount;
  final Set<String> unlockedAchievements;

  const ProfileTab({
    super.key,
    required this.level,
    required this.xp,
    required this.streak,
    required this.collectedCount,
    required this.unlockedAchievements,
  });

  @override
  Widget build(BuildContext context) {
    final nextLevelXp = xpForNextLevel(level);
    final progress = xp / nextLevelXp;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar ring
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
          Text(levelTitle(level),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber))
              .animate().fadeIn(delay: 100.ms),
          Text('Level $level', style: const TextStyle(fontSize: 16, color: Colors.white54)),
          const SizedBox(height: 20),
          // XP Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('XP Progress', style: TextStyle(color: Colors.white70)),
                Text('$xp / $nextLevelXp', style: const TextStyle(color: Colors.amber)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: bgCard,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 20),
          // Stats row
          Row(
            children: [
              _statCard('🔥', '$streak', 'Day Streak'),
              const SizedBox(width: 12),
              _statCard('🐦', '$collectedCount', 'Species'),
              const SizedBox(width: 12),
              _statCard('🏆', '${unlockedAchievements.length}', 'Badges'),
            ],
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
          // Achievements
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Achievements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: achievements.entries.map((e) {
              final unlocked = unlockedAchievements.contains(e.key);
              return Tooltip(
                message: unlocked ? e.value.$3 : '???',
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
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 24),
          // Eco impact
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
          ).animate().fadeIn(delay: 300.ms),
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
}
