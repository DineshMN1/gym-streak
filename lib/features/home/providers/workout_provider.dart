import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Calculated streak data from workout logs
final streakDataProvider = Provider<({int current, int best, int total})>((ref) {
  final logsAsync = ref.watch(workoutLogsProvider);
  return logsAsync.when(
    data: (logs) => _calculateStreak(logs),
    loading: () => (current: 0, best: 0, total: 0),
    error: (_, _) => (current: 0, best: 0, total: 0),
  );
});

({int current, int best, int total}) _calculateStreak(List<WorkoutLog> logs) {
  if (logs.isEmpty) return (current: 0, best: 0, total: logs.length);

  final dates =
      logs
          .map((log) => DateTime.parse(log.date))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a)); // newest first

  int currentStreak = 0;
  int bestStreak = 0;
  int tempStreak = 1;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Check if today or yesterday has a log (to allow for active streaks)
  if (dates.isNotEmpty) {
    final latest = dates.first;
    final diff = today.difference(latest).inDays;
    if (diff > 1) {
      // Streak is broken
      currentStreak = 0;
    } else {
      currentStreak = 1;
      for (int i = 1; i < dates.length; i++) {
        final diffBetween = dates[i - 1].difference(dates[i]).inDays;
        if (diffBetween == 1) {
          currentStreak++;
        } else {
          break;
        }
      }
    }
  }

  // Calculate best streak
  tempStreak = 1;
  bestStreak = 1;
  for (int i = 1; i < dates.length; i++) {
    final diffBetween = dates[i - 1].difference(dates[i]).inDays;
    if (diffBetween == 1) {
      tempStreak++;
      if (tempStreak > bestStreak) bestStreak = tempStreak;
    } else {
      tempStreak = 1;
    }
  }

  if (dates.isEmpty) bestStreak = 0;

  return (
    current: currentStreak,
    best: bestStreak < currentStreak ? currentStreak : bestStreak,
    total: logs.length,
  );
}
