import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local notification service for streak reminders and daily dog alerts.
///
/// Uses flutter_local_notifications — no Firebase/FCM required.
/// All scheduling is on-device with exact alarms that survive reboots.
class NotificationService {
  static final _log = Logger('NotificationService');

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _streakChannelId = 'hound_streak';
  static const _streakChannelName = 'Streak Reminders';
  static const _dailyDogChannelId = 'hound_daily_dog';
  static const _dailyDogChannelName = 'Daily Dog Alerts';

  static const _streakNotificationId = 1001;
  static const _dailyDogNotificationId = 1002;

  /// Hive box key names for notification preferences
  static const keyStreakReminders = 'notif_streak_reminders';
  static const keyDailyDogAlerts = 'notif_daily_dog_alerts';

  /// Initialize the notification plugin and timezone data.
  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request notification permission on Android 13+
    await _requestPermission();
  }

  /// Request POST_NOTIFICATIONS permission (Android 13+ / API 33+).
  static Future<void> _requestPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      _log.fine('Permission result: $result');
    }
  }

  /// Callback when user taps a notification.
  static void _onNotificationTapped(NotificationResponse response) {
    _log.fine('Tapped: ${response.payload}');
  }

  // ─── Streak Reminder (8 PM daily) ───────────────────────────────────────

  /// Schedule a daily streak reminder at 8:00 PM local time.
  static Future<void> scheduleStreakReminder() async {
    await _plugin.zonedSchedule(
      _streakNotificationId,
      "Don't break your streak!",
      'Open Hound to keep your identifying streak alive!',
      _nextInstanceOfTime(20, 0), // 8:00 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _streakChannelId,
          _streakChannelName,
          channelDescription:
              'Daily reminder to maintain your identifying streak',
          importance: Importance.high,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'streak_reminder',
    );
    _log.fine('Streak reminder scheduled for 8:00 PM daily');
  }

  /// Cancel the streak reminder.
  static Future<void> cancelStreakReminder() async {
    await _plugin.cancel(_streakNotificationId);
    _log.fine('Streak reminder cancelled');
  }

  // ─── Daily Dog Alert (9 AM daily) ─────────────────────────────────────

  /// Schedule a daily dog-of-the-day alert at 9:00 AM local time.
  static Future<void> scheduleDailyDogReminder() async {
    await _plugin.zonedSchedule(
      _dailyDogNotificationId,
      'New Dog of the Day!',
      'A new daily dog challenge is waiting. 3x XP bonus!',
      _nextInstanceOfTime(9, 0), // 9:00 AM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyDogChannelId,
          _dailyDogChannelName,
          channelDescription: 'Daily notification about the dog of the day',
          importance: Importance.high,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_dog',
    );
    _log.fine('Daily dog reminder scheduled for 9:00 AM daily');
  }

  /// Cancel the daily dog alert.
  static Future<void> cancelDailyDogReminder() async {
    await _plugin.cancel(_dailyDogNotificationId);
    _log.fine('Daily dog reminder cancelled');
  }

  // ─── Utility ───────────────────────────────────────────────────────────

  /// Cancel all scheduled notifications (e.g. on logout).
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _log.fine('All notifications cancelled');
  }

  /// Returns the next occurrence of [hour]:[minute] in local timezone.
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

  // ─── Preference Helpers ────────────────────────────────────────────────

  /// Read whether streak reminders are enabled (defaults to true).
  static bool get streakRemindersEnabled {
    final box = Hive.box('dogquest_player_stats');
    return box.get(keyStreakReminders, defaultValue: true) as bool;
  }

  /// Read whether daily dog alerts are enabled (defaults to true).
  static bool get dailyDogAlertsEnabled {
    final box = Hive.box('dogquest_player_stats');
    return box.get(keyDailyDogAlerts, defaultValue: true) as bool;
  }

  /// Toggle streak reminders on/off and persist preference.
  static Future<void> setStreakReminders(bool enabled) async {
    final box = Hive.box('dogquest_player_stats');
    await box.put(keyStreakReminders, enabled);
    if (enabled) {
      await scheduleStreakReminder();
    } else {
      await cancelStreakReminder();
    }
  }

  /// Toggle daily dog alerts on/off and persist preference.
  static Future<void> setDailyDogAlerts(bool enabled) async {
    final box = Hive.box('dogquest_player_stats');
    await box.put(keyDailyDogAlerts, enabled);
    if (enabled) {
      await scheduleDailyDogReminder();
    } else {
      await cancelDailyDogReminder();
    }
  }

  /// Schedule all enabled notifications based on saved preferences.
  static Future<void> scheduleFromPreferences() async {
    if (streakRemindersEnabled) {
      await scheduleStreakReminder();
    }
    if (dailyDogAlertsEnabled) {
      await scheduleDailyDogReminder();
    }
  }
}
