import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/workout_type.dart';
import 'package:gym_streak/models/workout_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A workout logged on the device but not yet accepted by the server.
@immutable
class PendingWorkout {
  const PendingWorkout({required this.date, required this.workoutType});

  final CalendarDate date;
  final WorkoutType workoutType;

  /// As it appears to the rest of the app. A pending workout counts towards the
  /// streak immediately — the user did the work, and hiding it until the
  /// network agrees is what makes offline logging feel broken.
  WorkoutLog toLog() => WorkoutLog(
    date: date,
    workoutType: workoutType,
    completedAt: DateTime.now(),
  );

  String encode() =>
      jsonEncode({'date': date.toIso(), 'type': workoutType.wire});

  static PendingWorkout? decode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final date = CalendarDate.tryParse('${map['date']}');
      final type = WorkoutType.fromWire('${map['type']}');
      if (date == null || type == null) return null;
      return PendingWorkout(date: date, workoutType: type);
    } catch (_) {
      // A truncated or older-format row must not make the whole queue
      // unreadable; that would strand every other pending workout with it.
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingWorkout &&
          other.date == date &&
          other.workoutType == workoutType;

  @override
  int get hashCode => Object.hash(date, workoutType);
}

/// Where the queue is kept. Abstract so the queue can be tested without
/// platform channels.
abstract interface class PendingWorkoutStore {
  Future<List<String>> read();
  Future<void> write(List<String> rows);
}

/// The real store.
class SharedPreferencesPendingStore implements PendingWorkoutStore {
  static const String _key = 'pending_workouts';

  @override
  Future<List<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  @override
  Future<void> write(List<String> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, rows);
  }
}

/// Workouts logged offline, waiting to reach the server.
///
/// A gym is a concrete box with no signal — that is the normal case here, not
/// an edge case. Without this, a failed write vanished silently and the user
/// discovered the loss a day later as a broken streak.
class PendingWorkoutQueue {
  PendingWorkoutQueue(this._store);

  final PendingWorkoutStore _store;

  Future<List<PendingWorkout>> pending() async {
    final rows = await _store.read();
    final out = <PendingWorkout>[];
    for (final row in rows) {
      final decoded = PendingWorkout.decode(row);
      if (decoded != null) out.add(decoded);
    }
    return out;
  }

  /// Queues [date]/[workoutType], replacing any existing entry for that day.
  ///
  /// One entry per date mirrors the database's unique `(user_id, date)`
  /// constraint: logging twice in a day is a correction, not a second workout.
  Future<void> enqueue(CalendarDate date, WorkoutType workoutType) async {
    final current = await pending()
      ..removeWhere((w) => w.date == date);
    current.add(PendingWorkout(date: date, workoutType: workoutType));
    await _store.write(current.map((w) => w.encode()).toList());
  }

  Future<void> remove(CalendarDate date) async {
    final current = await pending()
      ..removeWhere((w) => w.date == date);
    await _store.write(current.map((w) => w.encode()).toList());
  }
}

/// Combines server logs with anything still queued locally.
///
/// A pending entry wins over a remote row for the same day: it is the newer
/// intent, made on this device.
List<WorkoutLog> mergePendingIntoLogs(
  List<WorkoutLog> remote,
  List<PendingWorkout> pending,
) {
  if (pending.isEmpty) return remote;

  final byDate = <CalendarDate, WorkoutLog>{
    for (final log in remote) log.date: log,
    for (final entry in pending) entry.date: entry.toLog(),
  };

  return byDate.values.toList()..sort(
    (a, b) => b.date.compareTo(a.date),
  ); // newest first, as the stream is
}
