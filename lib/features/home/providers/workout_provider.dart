import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/streak/streak_engine.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';
import 'package:gym_streak/features/auth/providers/auth_provider.dart';
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

final todayWorkoutProvider = StreamProvider<WorkoutLog?>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return Stream.value(null);
  return ref.watch(workoutRepositoryProvider).todayWorkoutStream(uid);
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
  final logsAsync = ref.watch(workoutLogsProvider);
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
