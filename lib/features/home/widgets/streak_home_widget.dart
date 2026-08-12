import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';
import 'package:gym_streak/features/home/providers/workout_provider.dart';
import 'package:home_widget/home_widget.dart';

/// Keys shared with the native widget. Changing one here without changing the
/// Kotlin side leaves the widget showing stale numbers forever, so they are
/// named constants on both sides rather than loose strings.
class StreakWidgetKeys {
  StreakWidgetKeys._();

  static const String current = 'current_streak';
  static const String best = 'best_streak';
  static const String total = 'total_workouts';

  /// Must match the Kotlin class name in
  /// `android/app/src/main/kotlin/.../StreakWidgetProvider.kt`.
  static const String androidProvider = 'StreakWidgetProvider';
}

/// Pushes streak figures out to the home-screen widget.
///
/// The widget cannot run Dart or reach Supabase — it renders whatever was last
/// written into shared storage. So the app is responsible for writing on every
/// change, and the widget only ever reads.
class StreakHomeWidget {
  StreakHomeWidget._();

  static Future<void> push(StreakStats stats) async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<int>(StreakWidgetKeys.current, stats.current),
        HomeWidget.saveWidgetData<int>(StreakWidgetKeys.best, stats.best),
        HomeWidget.saveWidgetData<int>(StreakWidgetKeys.total, stats.total),
      ]);
      await HomeWidget.updateWidget(
        androidName: StreakWidgetKeys.androidProvider,
      );
    } catch (error) {
      // A home-screen widget is a nicety. If the platform channel is missing —
      // web, macOS, a test harness — or the update fails, the app itself must
      // carry on regardless.
      debugPrint('Home widget update skipped: $error');
    }
  }
}

/// Keeps the home-screen widget in step with [streakDataProvider].
///
/// Watched from the app root so it stays alive for the session. `StreakStats`
/// has value equality, so this fires only when the numbers actually change
/// rather than on every stream emission.
final streakWidgetSyncProvider = Provider<void>((ref) {
  ref.listen<StreakStats>(streakDataProvider, (previous, next) {
    if (previous == next) return;
    StreakHomeWidget.push(next);
  }, fireImmediately: true);
});
