import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import '../helpers/game_helpers.dart';
import '../services/activity_tracker_service.dart';
import '../services/kennel_service.dart';
import '../services/dog_group_service.dart';
import '../services/dog_mastery_service.dart';
import '../services/dog_service.dart';
import '../services/player_service.dart';
import '../services/seasonal_event_service.dart';
import '../services/my_dog_service.dart';
import '../services/pack_service.dart';
import '../services/sighting_service.dart';
import '../widgets/collection_heatmap.dart';
import '../widgets/community_pulse.dart';
import '../widgets/daily_challenges_card.dart';
import '../widgets/level_progress_ring.dart';
import '../widgets/personal_insights_card.dart';
import '../widgets/rarity_collection_wheel.dart';
import '../widgets/recommended_dogs_strip.dart';
import '../widgets/streak_fire_widget.dart';
import '../widgets/weekly_mission_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final kennelSvc = ref.read(kennelServiceProvider);
    final dogSvc = ref.read(dogServiceProvider);
    final familySvc = ref.read(dogGroupServiceProvider);
    final sightingSvc = ref.read(sightingServiceProvider);
    final seasonalSvc = ref.read(seasonalEventServiceProvider);
    final masteryState = ref.watch(dogMasteryProvider);
    final nextLevelXp = playerState.xpForNextLevel;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // ─── Greeting ───────────────────────────────────────────
          _UserGreeting(),
          const SizedBox(height: 12),

          // ─── Top Bar ────────────────────────────────────────────
          Row(
            children: [
              // Streak fire (left side, prominent)
              if (playerState.streak > 0)
                StreakFireWidget(
                  streak: playerState.streak,
                  xpMultiplier: playerState.streakXpMultiplier,
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.dynamic_feed_rounded,
                    color: Colors.white54, size: 22),
                onPressed: () => context.push('/feed'),
                tooltip: 'Dog Feed',
              ),
              IconButton(
                icon: const Icon(Icons.explore_rounded,
                    color: Colors.white54, size: 22),
                onPressed: () => context.push('/dogs-nearby'),
                tooltip: 'Dogs Nearby',
              ),
              IconButton(
                icon: const Icon(Icons.leaderboard_rounded,
                    color: Colors.white54, size: 22),
                onPressed: () => context.push('/leaderboard'),
                tooltip: 'Leaderboard',
              ),
              IconButton(
                icon: const Icon(Icons.people_rounded,
                    color: Colors.white54, size: 22),
                onPressed: () => context.push('/friends'),
                tooltip: 'Friends',
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded,
                    color: Colors.amber, size: 22),
                onPressed: () => context.push('/lost-dog'),
                tooltip: 'Lost Dog Network',
              ),
              IconButton(
                icon:
                    const Icon(Icons.settings, color: Colors.white54, size: 22),
                onPressed: () => context.push('/settings'),
                tooltip: 'Settings',
              ),
            ],
          ),

          // My Dog card
          _MyDogCard(),
          const SizedBox(height: 4),

          // Pack card
          _PackCard(),
          const SizedBox(height: 8),

          // Sign-in prompt for offline users
          if (Hive.box('dogquest_player_stats')
                  .get('offline_mode', defaultValue: false) ==
              true)
            _buildSignInPrompt(context),

          const SizedBox(height: 8),

          // ─── Level Progress Ring ────────────────────────────────
          LevelProgressRing(
            level: playerState.level,
            xp: playerState.xp,
            xpForNext: nextLevelXp,
            streakMultiplier: playerState.streakXpMultiplier,
          ).animate().fadeIn(),
          const SizedBox(height: 20),

          // ─── Stats Grid ─────────────────────────────────────────
          Row(
            children: [
              _StatTile(
                  icon: Icons.catching_pokemon,
                  value: '${kennelSvc.count}',
                  label: 'Breeds',
                  color: Colors.amber),
              const SizedBox(width: 10),
              _StatTile(
                  icon: Icons.visibility,
                  value: '${sightingSvc.totalSightings}',
                  label: 'Sightings',
                  color: const Color(0xFFD4874E)),
              const SizedBox(width: 10),
              _StatTile(
                  icon: Icons.emoji_events,
                  value: '${playerState.unlockedAchievements.length}',
                  label: 'Badges',
                  color: const Color(0xFF7C4DFF)),
            ],
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatTile(
                  icon: Icons.quiz,
                  value: '${playerState.quizzesCompleted}',
                  label: 'Quizzes',
                  color: const Color(0xFF2196F3)),
              const SizedBox(width: 10),
              _StatTile(
                  icon: Icons.account_tree,
                  value: '${familySvc.completedFamilies}',
                  label: 'Families',
                  color: const Color(0xFFFF9800)),
              const SizedBox(width: 10),
              _StatTile(
                  icon: Icons.workspace_premium,
                  value: '${masteryState.totalMastered}',
                  label: 'Mastered',
                  color: Colors.amber),
            ],
          ).animate().fadeIn(delay: 150.ms),

          // Best streak + streak savers
          if (playerState.bestStreak > 1 || playerState.streakSavers > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (playerState.bestStreak > 1)
                  _MiniInfoChip(
                      icon: Icons.military_tech,
                      text: 'Best: ${playerState.bestStreak} days',
                      color: Colors.orange),
                if (playerState.bestStreak > 1 && playerState.streakSavers > 0)
                  const SizedBox(width: 10),
                if (playerState.streakSavers > 0)
                  _MiniInfoChip(
                      icon: Icons.shield,
                      text:
                          '${playerState.streakSavers} streak saver${playerState.streakSavers > 1 ? 's' : ''}',
                      color: const Color(0xFFD4874E)),
              ],
            ).animate().fadeIn(delay: 180.ms),
          ],

          // Active XP Bonuses
          ..._buildActiveBonuses(playerState, seasonalSvc),

          const SizedBox(height: 20),

          // ─── Personal Insights ────────────────────────────────────
          const PersonalInsightsCard(),
          const SizedBox(height: 12),

          // ─── Daily Challenges ───────────────────────────────────
          const DailyChallengesCard(),
          const SizedBox(height: 6),

          // ─── Weekly Mission ─────────────────────────────────────
          const WeeklyMissionCard(),
          const SizedBox(height: 16),

          // ─── Recommended Dogs ──────────────────────────────────
          const RecommendedDogsStrip(),
          const SizedBox(height: 24),

          // ─── Collection + Mastery Row ───────────────────────────
          _SectionHeader(title: 'Collection', icon: Icons.collections_bookmark),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rarity Wheel
              Expanded(
                child: RarityCollectionWheel(
                  segments: [
                    for (final r in [
                      Rarity.common,
                      Rarity.uncommon,
                      Rarity.rare,
                      Rarity.legendary
                    ])
                      RaritySegment(
                        rarity: r,
                        collected: kennelSvc.collectedDogs
                            .where((b) => b.rarity == r)
                            .length,
                        total: dogSvc.all.where((b) => b.rarity == r).length,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Mastery breakdown
              Expanded(
                child: _MasterySummary(
                    mastery: masteryState, totalDogs: dogSvc.all.length),
              ),
            ],
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 24),

          // ─── Activity Heatmap ───────────────────────────────────
          _SectionHeader(title: 'Activity', icon: Icons.grid_on),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                CollectionHeatmap(activityData: ref.watch(activityMapProvider)),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 24),

          // ─── Next Achievements ──────────────────────────────────
          ..._buildNextAchievements(playerState, kennelSvc, dogSvc),

          // ─── All Achievements Grid ──────────────────────────────
          _SectionHeader(
              title: 'Achievements',
              icon: Icons.emoji_events,
              subtitle:
                  '${playerState.unlockedAchievements.length}/${achievements.length}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: achievements.entries.map((e) {
              final unlocked = playerState.unlockedAchievements.contains(e.key);
              return Tooltip(
                message: unlocked ? '${e.value.$2}: ${e.value.$3}' : e.value.$3,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? Colors.amber.withValues(alpha: 0.12)
                        : bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: unlocked
                          ? Colors.amber.withValues(alpha: 0.5)
                          : Colors.white10,
                      width: unlocked ? 1.5 : 1,
                    ),
                    boxShadow: unlocked
                        ? [
                            BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.08),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      unlocked ? e.value.$1 : '\u{1F512}',
                      style: TextStyle(
                          fontSize: 24,
                          color: unlocked ? null : Colors.white24),
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 24),

          // ─── Community Pulse ──────────────────────────────────────
          const CommunityPulse(),
          const SizedBox(height: 16),

          // ─── Eco Impact ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1B5E20).withValues(alpha: 0.3),
                  bgCard,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFD4874E).withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4874E).withValues(alpha: 0.15),
                ),
                child:
                    const Icon(Icons.eco, color: Color(0xFFD4874E), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Eco Impact',
                        style: TextStyle(
                            color: Color(0xFFD4874E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    SizedBox(height: 2),
                    Text(
                        'Every breed identified helps grow the DogQuest community.',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ])),
            ]),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cloud_off_rounded,
                color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Offline mode",
                    style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                const Text('Sign in to sync your collection.',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05);
  }

  List<Widget> _buildActiveBonuses(
      PlayerState playerState, SeasonalEventService seasonalSvc) {
    final widgets = <Widget>[];
    final event = seasonalSvc.primaryEvent;

    if (playerState.streakXpMultiplier > 1.0) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.orange.withValues(alpha: 0.12),
              Colors.red.withValues(alpha: 0.06),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.trending_up, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Text(
                '+${((playerState.streakXpMultiplier - 1) * 100).round()}% XP from streak',
                style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ).animate().fadeIn(delay: 200.ms),
      );
    }

    if (event != null) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              event.themeColor.withValues(alpha: 0.12),
              event.themeColor.withValues(alpha: 0.04),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: event.themeColor.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Text(event.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  '${event.name} — ${event.xpMultiplier}x XP (${event.daysRemaining}d left)',
                  style: TextStyle(
                      color: event.themeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ).animate().fadeIn(delay: 220.ms),
      );
    }

    return widgets;
  }

  List<Widget> _buildNextAchievements(
      PlayerState playerState, KennelService kennelSvc, DogService dogSvc) {
    final unlocked = playerState.unlockedAchievements;
    final hints = <_AchievementHint>[];

    final count = kennelSvc.count;
    final milestones = [
      (5, 'five_species'),
      (10, 'ten_species'),
      (20, 'twenty_species'),
      (50, 'fifty_species'),
      (100, 'hundred_species'),
      (200, 'two_hundred_species'),
    ];
    for (final (target, key) in milestones) {
      if (!unlocked.contains(key) && count > 0) {
        final remaining = target - count;
        if (remaining > 0 && remaining <= target) {
          hints.add(_AchievementHint(
              key: key,
              progress: count / target,
              hint: '$remaining more species'));
        }
        break;
      }
    }

    final collectedDogs = kennelSvc.collectedDogs;
    final rareCount =
        collectedDogs.where((b) => b.rarity == Rarity.rare).length;
    if (!unlocked.contains('five_rare') && rareCount > 0) {
      hints.add(_AchievementHint(
          key: 'five_rare',
          progress: rareCount / 5,
          hint: '${5 - rareCount} more rare'));
    }
    final legendaryCount =
        collectedDogs.where((b) => b.rarity == Rarity.legendary).length;
    if (!unlocked.contains('five_legendary') && legendaryCount > 0) {
      hints.add(_AchievementHint(
          key: 'five_legendary',
          progress: legendaryCount / 5,
          hint: '${5 - legendaryCount} more legendary'));
    }

    final streak = playerState.streak;
    final streakMilestones = [
      (3, 'streak_3'),
      (7, 'streak_7'),
      (30, 'streak_30')
    ];
    for (final (target, key) in streakMilestones) {
      if (!unlocked.contains(key) && streak > 0) {
        hints.add(_AchievementHint(
            key: key,
            progress: streak / target,
            hint: '${target - streak} more days'));
        break;
      }
    }

    final quizzes = playerState.quizzesCompleted;
    if (!unlocked.contains('ten_quizzes') && quizzes > 0 && quizzes < 10) {
      hints.add(_AchievementHint(
          key: 'ten_quizzes',
          progress: quizzes / 10,
          hint: '${10 - quizzes} more quizzes'));
    }

    if (hints.isEmpty) return [];

    hints.sort((a, b) => b.progress.compareTo(a.progress));
    final displayHints = hints.take(3).toList();

    return [
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.track_changes, color: Colors.amber, size: 16),
              SizedBox(width: 6),
              Text('Next Up',
                  style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            ...displayHints.map((hint) {
              final achievement = achievements[hint.key];
              if (achievement == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text(achievement.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(achievement.$2,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: hint.progress.clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                hint.progress >= 0.75
                                    ? Colors.amber
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${(hint.progress * 100).round()}%',
                          style: TextStyle(
                            color: hint.progress >= 0.75
                                ? Colors.amber
                                : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                      Text(hint.hint,
                          style: const TextStyle(
                              color: Colors.white30, fontSize: 9)),
                    ],
                  ),
                ]),
              );
            }),
          ],
        ),
      ).animate().fadeIn(delay: 320.ms),
    ];
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;

  const _SectionHeader(
      {required this.title, required this.icon, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(subtitle!,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
        const Spacer(),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MiniInfoChip(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _MasterySummary extends StatelessWidget {
  final DogMasteryState mastery;
  final int totalDogs;

  const _MasterySummary({required this.mastery, required this.totalDogs});

  @override
  Widget build(BuildContext context) {
    final levels = [
      (DogMasteryLevel.master, mastery.totalMastered),
      (DogMasteryLevel.expert, mastery.totalExpert),
      (DogMasteryLevel.familiar, mastery.totalFamiliar),
      (DogMasteryLevel.spotted, mastery.totalSpotted),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mastery',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 10),
        ...levels.map((entry) {
          final (level, count) = entry;
          final fraction = totalDogs > 0 ? count / totalDogs : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(level.icon, color: level.color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(level.label,
                              style: TextStyle(
                                  color: level.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          Text('$count',
                              style: TextStyle(
                                  color: level.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(level.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(
          '${mastery.sightingCounts.length}/$totalDogs tracked',
          style: const TextStyle(color: Colors.white30, fontSize: 10),
        ),
      ],
    );
  }
}

class _UserGreeting extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerBox = Hive.box('dogquest_player_stats');
    final username =
        playerBox.get('cached_username', defaultValue: null) as String?;
    final displayName =
        (username != null && username.isNotEmpty) ? username : 'Doger';
    final playerState = ref.watch(playerProvider);
    final customPhotoPath = Hive.box('dogquest_player_stats')
        .get('custom_avatar_path', defaultValue: '') as String;
    final isCustomPhoto = playerState.selectedAvatar == 'custom' &&
        customPhotoPath.isNotEmpty &&
        File(customPhotoPath).existsSync();
    final avatar = avatarOptions.firstWhere(
      (a) => a.id == playerState.selectedAvatar,
      orElse: () => avatarOptions.first,
    );

    return Row(
      children: [
        GestureDetector(
          onTap: () => _showAvatarPicker(context, ref),
          child: Stack(
            children: [
              isCustomPhoto
                  ? CircleAvatar(
                      radius: 22,
                      backgroundImage: FileImage(File(customPhotoPath)),
                    )
                  : CircleAvatar(
                      radius: 22,
                      backgroundColor: avatar.bgColor.withValues(alpha: 0.25),
                      child: Text(avatar.emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: bgDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child:
                      const Icon(Icons.edit, size: 10, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Hello, $displayName!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showAvatarPicker(BuildContext context, WidgetRef ref) {
    final playerState = ref.read(playerProvider);
    final kennelSvc = ref.read(kennelServiceProvider);
    final kennelCount = kennelSvc.all.length;
    final customPath = Hive.box('dogquest_player_stats')
        .get('custom_avatar_path', defaultValue: '') as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => _AvatarPickerSheet(
          scrollController: scrollController,
          playerState: playerState,
          kennelCount: kennelCount,
          customPhotoPath: customPath,
          onSelect: (id) {
            ref.read(playerProvider.notifier).setAvatar(id);
            Navigator.pop(ctx);
          },
          onPickPhoto: () async {
            final picked = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 512,
              maxHeight: 512,
              imageQuality: 85,
            );
            if (picked == null) return;
            final appDir = await getApplicationDocumentsDirectory();
            final savedPath = '${appDir.path}/custom_avatar.jpg';
            await File(picked.path).copy(savedPath);
            Hive.box('dogquest_player_stats')
                .put('custom_avatar_path', savedPath);
            ref.read(playerProvider.notifier).setAvatar('custom');
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ),
    );
  }
}

class _AvatarPickerSheet extends StatelessWidget {
  final ScrollController scrollController;
  final PlayerState playerState;
  final int kennelCount;
  final String customPhotoPath;
  final void Function(String id) onSelect;
  final VoidCallback onPickPhoto;

  const _AvatarPickerSheet({
    required this.scrollController,
    required this.playerState,
    required this.kennelCount,
    required this.customPhotoPath,
    required this.onSelect,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    // +1 for the custom photo tile at the end
    final totalItems = avatarOptions.length + 1;
    final hasCustomPhoto =
        customPhotoPath.isNotEmpty && File(customPhotoPath).existsSync();

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Choose Avatar',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Unlock more by collecting breeds and earning achievements',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: totalItems,
            itemBuilder: (_, i) {
              // Last tile = custom photo
              if (i == avatarOptions.length) {
                final isSelected = playerState.selectedAvatar == 'custom';
                return GestureDetector(
                  onTap: onPickPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: hasCustomPhoto
                          ? Colors.teal
                              .withValues(alpha: isSelected ? 0.3 : 0.1)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Colors.amber
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasCustomPhoto)
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: FileImage(File(customPhotoPath)),
                          )
                        else
                          Icon(Icons.add_a_photo_rounded,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 28),
                        const SizedBox(height: 6),
                        Text(
                          hasCustomPhoto ? 'My Photo' : 'Upload Photo',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasCustomPhoto
                              ? 'Tap to change'
                              : 'Use your own photo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final avatar = avatarOptions[i];
              final unlocked = avatar.isUnlocked(
                playerState.level,
                kennelCount,
                playerState.unlockedAchievements,
                playerState.streak,
                playerState.totalSightings,
              );
              final isSelected = playerState.selectedAvatar == avatar.id;

              return GestureDetector(
                onTap: unlocked ? () => onSelect(avatar.id) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: unlocked
                        ? avatar.bgColor
                            .withValues(alpha: isSelected ? 0.3 : 0.1)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Colors.amber
                          : unlocked
                              ? avatar.bgColor.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.05),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (unlocked)
                        Text(avatar.emoji, style: const TextStyle(fontSize: 32))
                      else
                        Icon(Icons.lock_rounded,
                            color: Colors.white.withValues(alpha: 0.15),
                            size: 32),
                      const SizedBox(height: 6),
                      Text(
                        avatar.name,
                        style: TextStyle(
                          color: unlocked ? Colors.white : Colors.white24,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          avatar.description,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unlocked ? Colors.white38 : Colors.white12,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MyDogCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myDogSvc = ref.read(myDogServiceProvider);
    final dogs = myDogSvc.dogs;

    if (dogs.isEmpty) {
      // No dogs yet — show "Add your dog" CTA
      return GestureDetector(
        onTap: () => context.push('/my-dog/wizard'),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.amber.withValues(alpha: 0.12),
              Colors.orange.withValues(alpha: 0.06),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pets, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Your Dog',
                        style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    SizedBox(height: 2),
                    Text('Create a profile for your furry friend — earn 50 XP!',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 16),
          ]),
        ),
      ).animate().fadeIn().slideY(begin: 0.05);
    }

    // Show registered dogs
    return Column(
      children: [
        ...dogs.map((dog) => GestureDetector(
              onTap: () => context
                  .push('/my-dog/profile/${Uri.encodeComponent(dog.name)}'),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  // Dog photo or placeholder
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: dog.photoPath != null &&
                            File(dog.photoPath!).existsSync()
                        ? Image.file(File(dog.photoPath!),
                            width: 52, height: 52, fit: BoxFit.cover)
                        : Container(
                            width: 52,
                            height: 52,
                            color: Colors.amber.withValues(alpha: 0.1),
                            child: const Icon(Icons.pets,
                                color: Colors.amber, size: 28),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dog.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Row(children: [
                            if (dog.breed != null)
                              Text(dog.breed!,
                                  style: const TextStyle(
                                      color: Colors.amber, fontSize: 12)),
                            if (dog.breed != null && dog.ageYears != null)
                              const Text(' \u2022 ',
                                  style: TextStyle(
                                      color: Colors.white24, fontSize: 12)),
                            if (dog.ageYears != null)
                              Text(
                                  '${dog.ageYears} yr${dog.ageYears == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                          ]),
                          if (dog.daysUntilCelebration != null &&
                              dog.daysUntilCelebration! <= 30)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.pink.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${dog.usesGotchaDay ? "Gotcha day" : "Birthday"} in ${dog.daysUntilCelebration} days!',
                                  style: const TextStyle(
                                      color: Colors.pink,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ]),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white24),
                ]),
              ),
            ).animate().fadeIn()),

        // Add another dog button
        if (dogs.length < 5)
          GestureDetector(
            onTap: () => context.push('/my-dog/wizard'),
            child: Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_circle_outline,
                    color: Colors.white.withValues(alpha: 0.3), size: 16),
                const SizedBox(width: 6),
                Text('Add another dog',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12)),
              ]),
            ),
          ),
      ],
    );
  }
}

class _PackCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packSvc = ref.read(packServiceProvider);
    final pack = packSvc.pack;

    if (pack == null) {
      // No pack — show CTA
      return GestureDetector(
        onTap: () => context.push('/pack'),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4, bottom: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF7C4DFF).withValues(alpha: 0.1),
              const Color(0xFF448AFF).withValues(alpha: 0.06),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.group_add,
                  color: Color(0xFF7C4DFF), size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start a Pack',
                        style: TextStyle(
                            color: Color(0xFF7C4DFF),
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(height: 2),
                    Text(
                        'Create a family group to share dogs & track stats together',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFF7C4DFF), size: 14),
          ]),
        ),
      ).animate().fadeIn().slideY(begin: 0.05);
    }

    // Show pack summary
    return GestureDetector(
      onTap: () => context.push('/pack'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(pack.emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pack.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                  '${pack.members.length} member${pack.members.length == 1 ? '' : 's'} \u2022 ${pack.totalDogs} dog${pack.totalDogs == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
          if (pack.weeklyActiveDays > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${pack.weeklyActiveDays}/7',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white24),
        ]),
      ),
    ).animate().fadeIn();
  }
}

class _AchievementHint {
  final String key;
  final double progress;
  final String hint;

  const _AchievementHint(
      {required this.key, required this.progress, required this.hint});
}
