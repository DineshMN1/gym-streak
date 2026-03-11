import 'package:gym_streak/models/workout_log.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> logWorkout({
    required String uid,
    required String workoutType,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _client.from('workouts').upsert({
      'user_id': uid,
      'date': today,
      'workout_type': workoutType,
      'completed_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,date');
  }

  Future<void> removeWorkout({
    required String uid,
    required String date,
  }) async {
    await _client
        .from('workouts')
        .delete()
        .eq('user_id', uid)
        .eq('date', date);
  }

  Stream<List<WorkoutLog>> workoutLogsStream(String uid) {
    return _client
        .from('workouts')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('completed_at', ascending: false)
        .map((rows) => rows.map((row) => WorkoutLog.fromMap(row)).toList());
  }

  Future<List<WorkoutLog>> getWorkoutLogs(String uid) async {
    final data = await _client
        .from('workouts')
        .select()
        .eq('user_id', uid)
        .order('completed_at', ascending: false);
    return data.map((row) => WorkoutLog.fromMap(row)).toList();
  }

  Stream<WorkoutLog?> todayWorkoutStream(String uid) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _client
        .from('workouts')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((rows) {
          final todayRows = rows.where((r) => r['date'] == today);
          if (todayRows.isEmpty) return null;
          return WorkoutLog.fromMap(todayRows.first);
        });
  }
}
