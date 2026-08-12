import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gym_streak/core/domain/weekday.dart';
import 'package:gym_streak/features/reminders/reminder_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Weekly "time to train" reminders on the user's scheduled days.
///
/// Streak products lose people to forgetting rather than to dissatisfaction,
/// and this app had no defence against that at all.
///
/// Reminders follow the training plan: nudging someone on a day they told us
/// they rest is noise, and noise is how an app earns itself a permanent
/// notification block.
class ReminderService {
  ReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _enabledKey = 'reminders_enabled';
  static const String _channelId = 'streak_reminders';

  bool _ready = false;

  /// Prepares the plugin and the timezone database.
  ///
  /// Timezone data is required because a weekly repeat must be anchored to a
  /// wall-clock time in a real zone; scheduling in UTC would drift by an hour
  /// across daylight saving — the same class of bug the streak engine had.
  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Asked for explicitly later, at a moment the request makes sense.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  /// Whether the user wants reminders. Defaults to off — turning notifications
  /// on without being asked is how apps get blocked.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled({
    required bool enabled,
    required Set<Weekday> scheduledDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      await requestPermission();
      await reschedule(scheduledDays);
    } else {
      await cancelAll();
    }
  }

  /// Asks the OS for permission. Safe to call more than once.
  Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
    return false;
  }

  /// Replaces every scheduled reminder with one per day in the plan.
  ///
  /// Cancel-then-schedule rather than diffing: the set is at most seven items,
  /// and a diff would have to track which ids were live, which is exactly the
  /// state that goes stale and leaves orphaned notifications behind.
  Future<void> reschedule(Set<Weekday> scheduledDays) async {
    await init();
    if (!await isEnabled()) return;

    await cancelAll();

    final now = DateTime.now();
    for (final day in reminderDaysFor(scheduledDays)) {
      final when = nextOccurrence(
        from: now,
        weekday: day,
        hour: defaultReminderHour,
      );
      try {
        await _plugin.zonedSchedule(
          id: reminderIdFor(day),
          title: 'Time to train',
          body: "Keep the chain going — log today's workout.",
          scheduledDate: tz.TZDateTime.from(when, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Workout reminders',
              channelDescription: 'Nudges on the days you plan to train',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (error) {
        // A reminder is a nicety. Never let it take the app down — for example
        // on a platform with no notification support.
        debugPrint('Could not schedule reminder for $day: $error');
      }
    }
  }

  Future<void> cancelAll() async {
    await init();
    for (final day in Weekday.values) {
      try {
        await _plugin.cancel(id: reminderIdFor(day));
      } catch (_) {
        // Nothing scheduled for that day; nothing to undo.
      }
    }
  }
}
