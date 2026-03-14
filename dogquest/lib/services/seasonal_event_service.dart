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
      // Spring Walkathon (March 23 - April 23)
      SeasonalEvent(
        id: 'spring_walkathon',
        name: 'Spring Walkathon',
        emoji: '🌸',
        description: 'Spring is here! Walk your dogs and identify breeds for 2x XP.',
        themeColor: const Color(0xFFD4874E),
        xpMultiplier: 2.0,
        startDate: DateTime(year, 3, 23),
        endDate: DateTime(year, 4, 23),
      ),
      // National Pet Week (May 1-7)
      SeasonalEvent(
        id: 'national_pet_week',
        name: 'National Pet Week',
        emoji: '🐾',
        description: 'Celebrate pets everywhere! All finds earn bonus XP.',
        themeColor: Colors.teal,
        xpMultiplier: 2.0,
        startDate: DateTime(year, 5, 1),
        endDate: DateTime(year, 5, 7),
      ),
      // Puppy Season (June 1-21)
      SeasonalEvent(
        id: 'puppy_season',
        name: 'Puppy Season',
        emoji: '🐶',
        description: 'Puppies everywhere! Find toy and small breeds for bonus XP.',
        themeColor: const Color(0xFFFF9800),
        xpMultiplier: 1.5,
        startDate: DateTime(year, 6, 1),
        endDate: DateTime(year, 6, 21),
      ),
      // National Dog Day (August 23-29)
      SeasonalEvent(
        id: 'national_dog_day',
        name: 'National Dog Day',
        emoji: '🐕',
        description: 'Celebrate our canine companions! 3x XP on all finds.',
        themeColor: Colors.blue,
        xpMultiplier: 3.0,
        startDate: DateTime(year, 8, 23),
        endDate: DateTime(year, 8, 29),
      ),
      // Howl-o-ween (October 1-31)
      SeasonalEvent(
        id: 'howl_o_ween',
        name: 'Howl-o-ween',
        emoji: '🎃',
        description: 'Spooky season! Find rare and legendary breeds for 2x XP.',
        themeColor: const Color(0xFFFF5722),
        xpMultiplier: 2.0,
        startDate: DateTime(year, 10, 1),
        endDate: DateTime(year, 10, 31),
      ),
      // Holiday Pup Parade (December 1-31)
      SeasonalEvent(
        id: 'holiday_pup_parade',
        name: 'Holiday Pup Parade',
        emoji: '🎄',
        description: 'Spread holiday cheer! Every breed identified earns bonus XP.',
        themeColor: Colors.red,
        xpMultiplier: 2.0,
        startDate: DateTime(year, 12, 1),
        endDate: DateTime(year, 12, 31),
      ),
      // Earth Day (April 22)
      SeasonalEvent(
        id: 'earth_day',
        name: 'Earth Day',
        emoji: '🌎',
        description: 'Protect our planet! Every breed identified earns 3x XP.',
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
