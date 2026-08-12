import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/workout_type.dart';

/// One logged workout — at most one per user per calendar day.
class WorkoutLog {
  const WorkoutLog({
    this.id,
    required this.date,
    required this.workoutType,
    required this.completedAt,
  });

  /// The database primary key. Null for a log that has not been inserted yet.
  final String? id;

  /// The calendar day this workout counts towards.
  final CalendarDate date;

  final WorkoutType workoutType;

  final DateTime completedAt;

  /// Decodes a PostgREST row, or returns null when the row cannot be trusted.
  ///
  /// A row is unusable when its date will not parse or its workout type is not
  /// one this build knows — both of which are expected when a newer client has
  /// written data, so callers skip the row rather than crashing.
  static WorkoutLog? fromMap(Map<String, dynamic> data) {
    final date = CalendarDate.tryParse('${data['date'] ?? ''}');
    if (date == null) return null;

    final type = WorkoutType.fromWire('${data['workout_type'] ?? ''}');
    if (type == null) return null;

    final completedAtRaw = data['completed_at'];
    final completedAt = completedAtRaw is String
        ? DateTime.tryParse(completedAtRaw) ?? DateTime.now()
        : DateTime.now();

    return WorkoutLog(
      id: data['id'] as String?,
      date: date,
      workoutType: type,
      completedAt: completedAt,
    );
  }

  /// The row to send to PostgREST.
  ///
  /// [id] is deliberately omitted so the database assigns it on insert and the
  /// `(user_id, date)` upsert can match an existing row.
  Map<String, dynamic> toMap(String uid) {
    return {
      'user_id': uid,
      'date': date.toIso(),
      'workout_type': workoutType.wire,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutLog &&
          other.id == id &&
          other.date == date &&
          other.workoutType == workoutType &&
          other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(id, date, workoutType, completedAt);

  @override
  String toString() =>
      'WorkoutLog(${date.toIso()}, ${workoutType.wire}, id: $id)';
}
