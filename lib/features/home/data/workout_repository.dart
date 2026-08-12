import 'package:gym_streak/core/domain/app_failure.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/workout_type.dart';
import 'package:gym_streak/features/home/data/pending_workout_queue.dart';
import 'package:gym_streak/models/workout_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutRepository {
  /// Injected so the repository is constructible without a live Supabase.
  WorkoutRepository(this._client, {PendingWorkoutQueue? queue})
    : _queue = queue ?? PendingWorkoutQueue(SharedPreferencesPendingStore());

  final SupabaseClient _client;
  final PendingWorkoutQueue _queue;

  PendingWorkoutQueue get queue => _queue;

  Future<void> logWorkout({
    required String uid,
    required WorkoutType workoutType,
  }) async {
    final today = CalendarDate.today();
    try {
      await guardFailures(
        () => _client.from('workouts').upsert({
          'user_id': uid,
          'date': today.toIso(),
          'workout_type': workoutType.wire,
          'completed_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,date'),
      );
      // A successful write is also the best signal that the network is back,
      // so drain anything that piled up while it was not.
      await flushPending(uid);
    } on OfflineFailure {
      // The gym has no signal. Keep the workout and return normally — the user
      // did the work, and telling them it failed is both wrong and the fastest
      // way to lose them.
      await _queue.enqueue(today, workoutType);
    }
  }

  /// Pushes queued workouts to the server, dropping each one as it lands.
  ///
  /// Safe to call at any time: it is a no-op when the queue is empty, and a
  /// failure leaves the remaining entries queued for the next attempt.
  Future<void> flushPending(String uid) async {
    final pending = await _queue.pending();
    for (final workout in pending) {
      try {
        await guardFailures(
          () => _client.from('workouts').upsert({
            'user_id': uid,
            'date': workout.date.toIso(),
            'workout_type': workout.workoutType.wire,
            'completed_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id,date'),
        );
        await _queue.remove(workout.date);
      } on OfflineFailure {
        // Still offline. Leave this and everything after it for next time.
        return;
      }
    }
  }

  Future<void> removeWorkout({
    required String uid,
    required String date,
  }) async {
    await guardFailures(
      () =>
          _client.from('workouts').delete().eq('user_id', uid).eq('date', date),
    );
  }

  Stream<List<WorkoutLog>> workoutLogsStream(String uid) {
    return guardFailureStream(
      _client
          .from('workouts')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('completed_at', ascending: false)
          .map(_decodeRows),
    );
  }

  Future<List<WorkoutLog>> getWorkoutLogs(String uid) async {
    final data = await guardFailures(
      () => _client
          .from('workouts')
          .select()
          .eq('user_id', uid)
          .order('completed_at', ascending: false),
    );
    return _decodeRows(data);
  }

  Stream<WorkoutLog?> todayWorkoutStream(String uid) {
    return guardFailureStream(
      _client.from('workouts').stream(primaryKey: ['id']).eq('user_id', uid).map(
        (rows) {
          // Recomputed per emission on purpose: evaluating it once when the
          // stream is built would freeze "today" at that moment, so an app left
          // open across midnight would keep checking yesterday's date.
          final today = CalendarDate.today().toIso();
          final todayRows = rows.where((r) => r['date'] == today);
          if (todayRows.isEmpty) return null;
          return WorkoutLog.fromMap(todayRows.first);
        },
      ),
    );
  }

  /// Decodes rows, skipping any this build cannot read.
  static List<WorkoutLog> _decodeRows(List<Map<String, dynamic>> rows) {
    final out = <WorkoutLog>[];
    for (final row in rows) {
      final log = WorkoutLog.fromMap(row);
      if (log != null) out.add(log);
    }
    return out;
  }
}
