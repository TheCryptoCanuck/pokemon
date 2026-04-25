import 'dart:math' show pow;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../helpers/date_helpers.dart';
import '../helpers/game_helpers.dart';
import '../services/player_service.dart';
import '../services/sighting_service.dart';
import '../services/kennel_service.dart';
import '../services/dog_mastery_service.dart';
import '../services/dog_service.dart';
import '../services/combo_service.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgNav,
        title: const Text('My Records',
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white70),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Records'),
            Tab(text: 'This Week'),
            Tab(text: 'All Time'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecordsTab(),
          _ThisWeekTab(),
          _AllTimeTab(),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 1: Personal Records
// =============================================================================

class _RecordsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final sightingSvc = ref.watch(sightingServiceProvider);
    final kennelSvc = ref.watch(kennelServiceProvider);
    final combo = ref.watch(comboProvider);

    final bestDay = sightingSvc.bestDay;
    final bestDaySightings = bestDay?.$2 ?? 0;

    final records = <_RecordItem>[
      _RecordItem(
        icon: Icons.local_fire_department_rounded,
        iconColor: Colors.orange,
        label: 'Best Streak',
        value: '${player.bestStreak}',
        unit: 'days',
      ),
      _RecordItem(
        icon: Icons.calendar_today_rounded,
        iconColor: Colors.teal,
        label: 'Best Single Day',
        value: '$bestDaySightings',
        unit: 'sightings',
        subtitle: bestDay != null ? _formatDateLabel(bestDay.$1) : null,
      ),
      _RecordItem(
        icon: Icons.bolt_rounded,
        iconColor: Colors.amber,
        label: 'Highest Combo',
        value: '${combo.count}',
        unit: 'chain',
        subtitle:
            combo.isActive ? '${combo.multiplier}x multiplier active' : null,
      ),
      _RecordItem(
        icon: Icons.pets_rounded,
        iconColor: const Color(0xFFD4874E),
        label: 'Unique Breeds Found',
        value: '${kennelSvc.count}',
        unit: 'breeds',
      ),
      _RecordItem(
        icon: Icons.visibility_rounded,
        iconColor: Colors.blue,
        label: 'Total Sightings',
        value: '${sightingSvc.totalSightings}',
        unit: 'encounters',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        return _buildRecordCard(records[index])
            .animate()
            .fadeIn(delay: Duration(milliseconds: 60 * index))
            .slideX(
                begin: 0.05, end: 0, delay: Duration(milliseconds: 60 * index));
      },
    );
  }

  Widget _buildRecordCard(_RecordItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 2),
                if (item.subtitle != null)
                  Text(item.subtitle!,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              Text(item.unit,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateLabel(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    final months = [
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
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    return '${months[month.clamp(1, 12)]} $day';
  }
}

class _RecordItem {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;
  final String? subtitle;

  const _RecordItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
    this.subtitle,
  });
}

// =============================================================================
// Tab 2: This Week (last 7 days bar chart)
// =============================================================================

class _ThisWeekTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sightingSvc = ref.watch(sightingServiceProvider);
    final now = DateTime.now();

    // Build last 7 days data
    final days = <_DayData>[];
    int maxCount = 0;
    int weekTotal = 0;

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = formatDateKey(date);
      final sightings = sightingSvc.all
          .where((s) => formatDateKey(s.timestamp) == dateKey)
          .length;
      if (sightings > maxCount) maxCount = sightings;
      weekTotal += sightings;
      days.add(_DayData(
        dayName: _shortDayName(date.weekday),
        count: sightings,
        isToday: i == 0,
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week summary header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This Week',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('$weekTotal',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    const Text('sightings',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Daily Avg',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text((weekTotal / 7).toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const Text('per day',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 24),

          // Bar chart
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Sightings',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.asMap().entries.map((entry) {
                      final index = entry.key;
                      final day = entry.value;
                      final barHeight =
                          maxCount > 0 ? (day.count / maxCount) * 140 : 0.0;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${day.count}',
                                style: TextStyle(
                                  color: day.isToday
                                      ? Colors.amber
                                      : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                height: barHeight > 0 ? barHeight : 4,
                                decoration: BoxDecoration(
                                  color: day.isToday
                                      ? Colors.amber
                                      : day.count > 0
                                          ? Colors.amber.withValues(alpha: 0.5)
                                          : Colors.white12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ).animate().scaleY(
                                    begin: 0,
                                    end: 1,
                                    alignment: Alignment.bottomCenter,
                                    delay: Duration(milliseconds: 100 * index),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                  ),
                              const SizedBox(height: 8),
                              Text(
                                day.dayName,
                                style: TextStyle(
                                  color: day.isToday
                                      ? Colors.amber
                                      : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: day.isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // Empty state hint
          if (weekTotal == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.pets, color: Colors.white24, size: 40),
                  SizedBox(height: 12),
                  Text('No sightings this week',
                      style: TextStyle(color: Colors.white54, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Go spot some dogs to fill up your chart!',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  String _shortDayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1) % 7];
  }
}

class _DayData {
  final String dayName;
  final int count;
  final bool isToday;

  const _DayData({
    required this.dayName,
    required this.count,
    required this.isToday,
  });
}

// =============================================================================
// Tab 3: All Time Career Stats
// =============================================================================

class _AllTimeTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final kennelSvc = ref.watch(kennelServiceProvider);
    final mastery = ref.watch(dogMasteryProvider);
    final sightingSvc = ref.watch(sightingServiceProvider);
    final dogSvc = ref.watch(dogServiceProvider);

    final totalBreeds = dogSvc.all.length;
    final totalAchievements = achievements.length;
    final unlockedCount = player.unlockedAchievements.length;

    // Calculate days active from sighting history
    final daysActive = sightingSvc.groupedByDate().length;

    // XP progress
    final xpProgress = player.xpProgress;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        children: [
          // Level & XP card
          _StatCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: Center(
                        child: Text('${player.level}',
                            style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.title,
                              style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                              '${player.xp} / ${player.xpForNextLevel} XP to next level',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xpProgress,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amber),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 12),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  child: _StatTile(
                    icon: Icons.pets_rounded,
                    iconColor: const Color(0xFFD4874E),
                    label: 'Breeds',
                    value: '${kennelSvc.count}',
                    subtitle: 'of $totalBreeds',
                    progress:
                        totalBreeds > 0 ? kennelSvc.count / totalBreeds : 0,
                  ),
                ).animate().fadeIn(delay: 60.ms),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  child: _StatTile(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: Colors.amber,
                    label: 'Mastered',
                    value: '${mastery.totalMastered}',
                    subtitle: '10+ sightings',
                    progress: kennelSvc.count > 0
                        ? mastery.totalMastered / kennelSvc.count
                        : 0,
                  ),
                ).animate().fadeIn(delay: 120.ms),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  child: _StatTile(
                    icon: Icons.emoji_events_rounded,
                    iconColor: Colors.purple,
                    label: 'Achievements',
                    value: '$unlockedCount',
                    subtitle: 'of $totalAchievements',
                    progress: totalAchievements > 0
                        ? unlockedCount / totalAchievements
                        : 0,
                  ),
                ).animate().fadeIn(delay: 180.ms),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  child: _StatTile(
                    icon: Icons.calendar_month_rounded,
                    iconColor: Colors.teal,
                    label: 'Days Active',
                    value: '$daysActive',
                    subtitle: 'total days',
                    progress: null,
                  ),
                ).animate().fadeIn(delay: 240.ms),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Current streak & sightings
          _StatCard(
            child: Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.orange,
                    label: 'Current Streak',
                    value: '${player.streak} days',
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.visibility_rounded,
                    iconColor: Colors.blue,
                    label: 'Total Sightings',
                    value: '${sightingSvc.totalSightings}',
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.star_rounded,
                    iconColor: Colors.amber,
                    label: 'Total XP',
                    value: _formatNumber(
                        player.xp + _totalXpFromLevels(player.level)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 12),

          // Mastery breakdown
          _StatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mastery Breakdown',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _MasteryRow(
                  level: DogMasteryLevel.master,
                  count: mastery.totalMastered,
                  total: kennelSvc.count,
                ),
                const SizedBox(height: 8),
                _MasteryRow(
                  level: DogMasteryLevel.expert,
                  count: mastery.totalExpert,
                  total: kennelSvc.count,
                ),
                const SizedBox(height: 8),
                _MasteryRow(
                  level: DogMasteryLevel.familiar,
                  count: mastery.totalFamiliar,
                  total: kennelSvc.count,
                ),
                const SizedBox(height: 8),
                _MasteryRow(
                  level: DogMasteryLevel.spotted,
                  count: mastery.totalSpotted,
                  total: kennelSvc.count,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 360.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Approximate total lifetime XP earned across all previous levels.
  int _totalXpFromLevels(int currentLevel) {
    int total = 0;
    for (int i = 1; i < currentLevel; i++) {
      total += (1000 * pow(i, 1.4)).round();
    }
    return total;
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// =============================================================================
// Shared Widgets
// =============================================================================

class _StatCard extends StatelessWidget {
  final Widget child;

  const _StatCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;
  final double? progress;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        if (progress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress!.clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              minHeight: 4,
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

class _MasteryRow extends StatelessWidget {
  final DogMasteryLevel level;
  final int count;
  final int total;

  const _MasteryRow({
    required this.level,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        Icon(level.icon, color: level.color, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(level.label,
              style: TextStyle(color: level.color, fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                  level.color.withValues(alpha: 0.7)),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text('$count',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      ],
    );
  }
}
