import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Contextual, personalized notification scheduler for DogQuest.
///
/// Schedules smart notifications based on player state (streak, challenges,
/// collection progress) to create habit-forming cues that bring users back.
///
/// This is a static utility class — call [scheduleAll] from main.dart at
/// startup and after each dog identification. The underlying notification
/// plugin is already initialized by [NotificationService.init].
class SmartNotificationService {
  SmartNotificationService._(); // prevent instantiation

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ─── Notification IDs ──────────────────────────────────────────────────

  static const int _streakRiskId = 100;
  static const int _morningMotivationId = 101;
  static const int _challengeExpiringId = 102;
  static const int _comebackId = 103;
  static const int _weeklyReminderId = 104;

  // ─── Channel ───────────────────────────────────────────────────────────

  static const _channelId = 'dogquest_smart';
  static const _channelName = 'Smart Reminders';
  static const _channelDescription =
      'Personalized reminders based on your activity';

  static NotificationDetails get _notificationDetails => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      );

  // ─── Public API ────────────────────────────────────────────────────────

  /// Schedule all smart notifications based on current player state.
  ///
  /// Call this at app startup and after each identification event.
  ///
  /// - [streak]: current consecutive-day streak count.
  /// - [challengesCompleted]: how many of today's 3 daily challenges are done.
  /// - [totalChallenges]: total daily challenges (typically 3).
  /// - [uncollectedDogNames]: names of dogs not yet in the user's kennel.
  /// - [uncollectedHabitat]: habitat string of one uncollected dog (for the
  ///   morning notification body). May be null if all dogs are collected.
  static Future<void> scheduleAll({
    required int streak,
    required int challengesCompleted,
    required int totalChallenges,
    required List<String> uncollectedDogNames,
    required String? uncollectedHabitat,
  }) async {
    // Cancel all existing smart notifications before rescheduling so we
    // always reflect the latest state.
    await cancelAll();

    await Future.wait([
      _scheduleStreakAtRisk(streak),
      _scheduleMorningMotivation(uncollectedDogNames, uncollectedHabitat),
      _scheduleChallengeExpiring(challengesCompleted, totalChallenges),
      _scheduleComeback(),
      _scheduleWeeklyMissionReminder(),
    ]);

    debugPrint('[SmartNotifications] All smart notifications scheduled');
  }

  /// Cancel all smart notifications.
  static Future<void> cancelAll() async {
    await Future.wait([
      _plugin.cancel(_streakRiskId),
      _plugin.cancel(_morningMotivationId),
      _plugin.cancel(_challengeExpiringId),
      _plugin.cancel(_comebackId),
      _plugin.cancel(_weeklyReminderId),
    ]);
    debugPrint('[SmartNotifications] All smart notifications cancelled');
  }

  // ─── Individual Schedulers ─────────────────────────────────────────────

  /// 1. Streak at Risk — 8 PM today if streak >= 2.
  static Future<void> _scheduleStreakAtRisk(int streak) async {
    if (streak < 2) return;

    final scheduledDate = _nextInstanceOfTime(20, 0);

    await _plugin.zonedSchedule(
      _streakRiskId,
      'Your $streak-day streak is in danger!',
      'Open DogQuest and spot a dog before midnight to keep your streak alive.',
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'smart_streak_risk',
    );
    debugPrint(
        '[SmartNotifications] Streak at risk scheduled for $scheduledDate');
  }

  /// 2. Morning Motivation — 8 AM daily.
  static Future<void> _scheduleMorningMotivation(
    List<String> uncollectedDogNames,
    String? uncollectedHabitat,
  ) async {
    final scheduledDate = _nextInstanceOfTime(8, 0);

    String body;
    if (uncollectedDogNames.isEmpty) {
      body = "Your daily challenges are ready! Can you sweep all three?";
    } else {
      final rng = Random();
      final dogName =
          uncollectedDogNames[rng.nextInt(uncollectedDogNames.length)];
      final habitat = uncollectedHabitat ?? 'various';
      body =
          "Can you spot a $dogName today? They're often found in $habitat areas.";
    }

    await _plugin.zonedSchedule(
      _morningMotivationId,
      'Good morning, dog lover!',
      body,
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'smart_morning_motivation',
    );
    debugPrint(
        '[SmartNotifications] Morning motivation scheduled for $scheduledDate');
  }

  /// 3. Challenge Expiring — 9 PM if 1 or 2 of 3 challenges are done.
  static Future<void> _scheduleChallengeExpiring(
    int challengesCompleted,
    int totalChallenges,
  ) async {
    // Only fire if partially complete (not zero, not all done).
    if (challengesCompleted <= 0 || challengesCompleted >= totalChallenges) {
      return;
    }

    final scheduledDate = _nextInstanceOfTime(21, 0);

    await _plugin.zonedSchedule(
      _challengeExpiringId,
      'Almost there!',
      "You've completed $challengesCompleted/$totalChallenges daily challenges. "
          'Finish them all for a 300 XP sweep bonus!',
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'smart_challenge_expiring',
    );
    debugPrint(
        '[SmartNotifications] Challenge expiring scheduled for $scheduledDate');
  }

  /// 4. Comeback — fires 48 hours after this scheduling call.
  static Future<void> _scheduleComeback() async {
    final scheduledDate =
        tz.TZDateTime.now(tz.local).add(const Duration(hours: 48));

    await _plugin.zonedSchedule(
      _comebackId,
      'The dogs miss you!',
      'New daily challenges and a weekly mission are waiting for you.',
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'smart_comeback',
    );
    debugPrint('[SmartNotifications] Comeback scheduled for $scheduledDate');
  }

  /// 5. Weekly Mission Reminder — Monday at 10 AM.
  static Future<void> _scheduleWeeklyMissionReminder() async {
    final scheduledDate = _nextInstanceOfDayAndTime(DateTime.monday, 10, 0);

    await _plugin.zonedSchedule(
      _weeklyReminderId,
      'New Weekly Mission',
      'A fresh weekly mission has arrived! Check it out for up to 1000 XP.',
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'smart_weekly_mission',
    );
    debugPrint(
        '[SmartNotifications] Weekly mission reminder scheduled for $scheduledDate');
  }

  // ─── Time Helpers ──────────────────────────────────────────────────────

  /// Returns the next occurrence of [hour]:[minute] in the local timezone.
  /// If that time has already passed today, returns tomorrow's instance.
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Returns the next occurrence of a given [weekday] at [hour]:[minute].
  /// If that day/time has already passed this week, returns next week's
  /// instance.
  static tz.TZDateTime _nextInstanceOfDayAndTime(
      int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
