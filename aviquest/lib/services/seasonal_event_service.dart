import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A seasonal or calendar-based event that drives engagement.
class SeasonalEvent {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color themeColor;
  final double xpMultiplier;
  final DateTime startDate;
  final DateTime endDate;

  const SeasonalEvent({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.themeColor,
    this.xpMultiplier = 1.0,
    required this.startDate,
    required this.endDate,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Days remaining in this event.
  int get daysRemaining {
    final remaining = endDate.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }
}

/// Manages date-based seasonal events with no backend dependency.
///
/// Events are defined statically and repeat yearly. The system
/// checks the current date and returns any active events.
class SeasonalEventService {
  /// Get events for the current year, adjusting dates to this year.
  List<SeasonalEvent> get _yearlyEvents {
    final year = DateTime.now().year;
    return [
      // Spring Migration (March-May)
      SeasonalEvent(
        id: 'spring_migration',
        name: 'Spring Migration',
        emoji: '🌸',
        description: 'Birds are on the move! Spot migratory species for 2x XP.',
        themeColor: const Color(0xFF4CAF50),
        xpMultiplier: 2.0,
        startDate: DateTime(year, 3, 1),
        endDate: DateTime(year, 5, 31),
      ),
      // World Migratory Bird Day (May — 2nd Saturday)
      SeasonalEvent(
        id: 'world_migratory_bird_day',
        name: 'World Migratory Bird Day',
        emoji: '🌍',
        description: 'Celebrate global bird migration! All identifications earn 3x XP today.',
        themeColor: Colors.teal,
        xpMultiplier: 3.0,
        startDate: nthWeekdayOfMonth(year, 5, DateTime.saturday, 2),
        endDate: nthWeekdayOfMonth(year, 5, DateTime.saturday, 2).add(const Duration(days: 1)),
      ),
      // Summer Nesting Season (June-July)
      SeasonalEvent(
        id: 'nesting_season',
        name: 'Nesting Season',
        emoji: '🪺',
        description: 'Baby birds everywhere! Find nesting species for bonus XP.',
        themeColor: const Color(0xFFFF9800),
        xpMultiplier: 1.5,
        startDate: DateTime(year, 6, 1),
        endDate: DateTime(year, 7, 31),
      ),
      // Fall Migration (September-November)
      SeasonalEvent(
        id: 'fall_migration',
        name: 'Fall Migration',
        emoji: '🍂',
        description: 'The great southern journey! Migratory species yield 2x XP.',
        themeColor: const Color(0xFFFF5722),
        xpMultiplier: 2.0,
        startDate: DateTime(year, 9, 1),
        endDate: DateTime(year, 11, 30),
      ),
      // Christmas Bird Count (December 14 - January 5)
      SeasonalEvent(
        id: 'christmas_bird_count',
        name: 'Christmas Bird Count',
        emoji: '🎄',
        description: 'Join the tradition! Every species identified earns 2x XP.',
        themeColor: Colors.red,
        xpMultiplier: 2.0,
        startDate: DateTime(year, 12, 14),
        endDate: DateTime(year + 1, 1, 5),
      ),
      // International Bird Day (January 5)
      SeasonalEvent(
        id: 'international_bird_day',
        name: 'National Bird Day',
        emoji: '🐦',
        description: 'Celebrate our feathered friends! 3x XP on all finds.',
        themeColor: Colors.blue,
        xpMultiplier: 3.0,
        startDate: DateTime(year, 1, 5),
        endDate: DateTime(year, 1, 6),
      ),
      // Earth Day (April 22)
      SeasonalEvent(
        id: 'earth_day',
        name: 'Earth Day',
        emoji: '🌎',
        description: 'Protect our planet! Conservation species earn 3x XP.',
        themeColor: const Color(0xFF2E7D32),
        xpMultiplier: 3.0,
        startDate: DateTime(year, 4, 22),
        endDate: DateTime(year, 4, 23),
      ),
    ];
  }

  /// Returns the nth occurrence of a weekday in a given month.
  static DateTime nthWeekdayOfMonth(int year, int month, int weekday, int n) {
    var date = DateTime(year, month, 1);
    int count = 0;
    while (count < n) {
      if (date.weekday == weekday) count++;
      if (count < n) date = date.add(const Duration(days: 1));
    }
    return date;
  }

  /// Currently active events (can be multiple at once).
  List<SeasonalEvent> get activeEvents =>
      _yearlyEvents.where((e) => e.isActive).toList();

  /// The highest XP multiplier from all active events (defaults to 1.0).
  double get currentXpMultiplier {
    final events = activeEvents;
    if (events.isEmpty) return 1.0;
    return events.map((e) => e.xpMultiplier).reduce((a, b) => a > b ? a : b);
  }

  /// The primary active event (highest multiplier), or null.
  SeasonalEvent? get primaryEvent {
    final events = activeEvents;
    if (events.isEmpty) return null;
    events.sort((a, b) => b.xpMultiplier.compareTo(a.xpMultiplier));
    return events.first;
  }
}

final seasonalEventServiceProvider = Provider<SeasonalEventService>((ref) {
  return SeasonalEventService();
});
