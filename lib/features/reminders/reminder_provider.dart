import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/features/reminders/reminder_service.dart';

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(FlutterLocalNotificationsPlugin());
});

/// Whether reminders are switched on. Off until the user asks for them.
final remindersEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(reminderServiceProvider).isEnabled();
});
