import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/workout_type.dart';
import 'package:gym_streak/models/workout_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> logWorkout({
    required String uid,
    required WorkoutType workoutType,
  }) async {
    final today = CalendarDate.today().toIso();
    await _client.from('workouts').upsert({
      'user_id': uid,
      'date': today,
      'workout_type': workoutType.wire,
      'completed_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,date');
  }

  Future<void> removeWorkout({
    required String uid,
    required String date,
  }) async {
    await _client.from('workouts').delete().eq('user_id', uid).eq('date', date);
  }

  Stream<List<WorkoutLog>> workoutLogsStream(String uid) {
    return _client
        .from('workouts')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('completed_at', ascending: false)
        .map(_decodeRows);
  }

  Future<List<WorkoutLog>> getWorkoutLogs(String uid) async {
    final data = await _client
        .from('workouts')
        .select()
        .eq('user_id', uid)
        .order('completed_at', ascending: false);
    return _decodeRows(data);
  }

  Stream<WorkoutLog?> todayWorkoutStream(String uid) {
    return _client
        .from('workouts')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((rows) {
          // Recomputed per emission on purpose: evaluating it once when the
          // stream is built would freeze "today" at that moment, so an app left
          // open across midnight would keep checking yesterday's date.
          final today = CalendarDate.today().toIso();
          final todayRows = rows.where((r) => r['date'] == today);
          if (todayRows.isEmpty) return null;
          return WorkoutLog.fromMap(todayRows.first);
        });
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
