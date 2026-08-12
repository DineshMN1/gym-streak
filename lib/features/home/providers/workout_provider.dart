import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/streak/streak_engine.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';
import 'package:gym_streak/features/auth/providers/auth_provider.dart';
import 'package:gym_streak/features/home/data/pending_workout_queue.dart';
import 'package:gym_streak/features/home/data/workout_repository.dart';
import 'package:gym_streak/models/workout_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(Supabase.instance.client);
});

final workoutLogsProvider = StreamProvider<List<WorkoutLog>>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return Stream.value([]);
  return ref.watch(workoutRepositoryProvider).workoutLogsStream(uid);
});

/// Today's workout, including one logged offline and not yet synced.
final todayWorkoutProvider = Provider<AsyncValue<WorkoutLog?>>((ref) {
  final today = CalendarDate.today();
  return ref.watch(visibleWorkoutLogsProvider).whenData((logs) {
    for (final log in logs) {
      if (log.date == today) return log;
    }
    return null;
  });
});

final remoteTodayWorkoutProvider = StreamProvider<WorkoutLog?>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return Stream.value(null);
  return ref.watch(workoutRepositoryProvider).todayWorkoutStream(uid);
});

/// Workouts logged on this device that the server has not accepted yet.
///
/// Refreshed by invalidating this provider after a log or a flush.
final pendingWorkoutsProvider = FutureProvider<List<PendingWorkout>>((ref) {
  return ref.watch(workoutRepositoryProvider).queue.pending();
});

/// Server logs plus anything still queued locally.
///
/// Everything that displays workouts reads this rather than
/// [workoutLogsProvider]. A workout logged in a basement has to count towards
/// the streak straight away — waiting for the network to agree is exactly what
/// makes offline logging feel broken.
final visibleWorkoutLogsProvider = Provider<AsyncValue<List<WorkoutLog>>>((
  ref,
) {
  final remote = ref.watch(workoutLogsProvider);
  final pending = ref.watch(pendingWorkoutsProvider).valueOrNull ?? const [];
  return remote.whenData((logs) => mergePendingIntoLogs(logs, pending));
});

/// Streak figures derived from the user's workout logs and training plan.
///
/// The plan is what stops a scheduled rest day from reading as a broken
/// streak. Until this existed, onboarding collected `preferredDays` and nothing
/// read it, so the app told users their streak was broken for resting exactly
/// when they said they would.
///
/// A profile that has not loaded, or one with no days chosen, yields an empty
/// set — which `StreakEngine` treats as "every day counts", the original
/// behaviour.
final streakDataProvider = Provider<StreakStats>((ref) {
  final logsAsync = ref.watch(visibleWorkoutLogsProvider);
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;

  return logsAsync.maybeWhen(
    data: (logs) => StreakEngine.calculate(
      dates: logs.map((log) => log.date),
      today: CalendarDate.today(),
      scheduledDays: profile?.preferredDays.toSet() ?? const {},
    ),
    orElse: () => StreakStats.empty,
  );
});
