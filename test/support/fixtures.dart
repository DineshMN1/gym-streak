import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/workout_type.dart';
import 'package:gym_streak/models/workout_log.dart';
import 'package:intl/intl.dart';

final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

/// The calendar date [days] before today, as `yyyy-MM-dd`.
///
/// Arithmetic runs in UTC on purpose. Subtracting a `Duration(days: 1)` from a
/// *local* DateTime lands on the same calendar date across a daylight-saving
/// spring-forward, which would make fixtures silently wrong twice a year.
String isoDaysAgo(int days, {DateTime? from}) {
  final now = from ?? DateTime.now();
  final base = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: days));
  return _isoDate.format(base);
}

WorkoutLog workoutLog(
  String isoDate, {
  WorkoutType type = WorkoutType.strength,
}) {
  return WorkoutLog(
    date: CalendarDate.tryParse(isoDate)!,
    workoutType: type,
    completedAt: DateTime.parse('${isoDate}T12:00:00Z'),
  );
}

/// One log per entry in [daysAgo], e.g. `[0, 1, 2]` = today and the two days before.
List<WorkoutLog> logsForDaysAgo(List<int> daysAgo, {DateTime? from}) {
  return daysAgo.map((d) => workoutLog(isoDaysAgo(d, from: from))).toList();
}
