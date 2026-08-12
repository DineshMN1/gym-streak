import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/streak/streak_engine.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';
import 'package:gym_streak/features/home/data/workout_repository.dart';
import 'package:gym_streak/models/workout_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository();
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

/// Streak figures derived from the user's workout logs.
final streakDataProvider = Provider<StreakStats>((ref) {
  final logsAsync = ref.watch(workoutLogsProvider);
  return logsAsync.maybeWhen(
    data: (logs) => StreakEngine.calculate(
      dates: logs.map((log) => log.date),
      today: CalendarDate.today(),
    ),
    orElse: () => StreakStats.empty,
  );
});
