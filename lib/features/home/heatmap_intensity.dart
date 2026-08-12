/// Heatmap shading, from the user's own weekly target.
///
/// The heatmap used to be binary — trained or not — while advertising a
/// three-step legend it never rendered, and `workoutsPerWeek` sat unused since
/// onboarding first asked for it. Both are fixed by the same idea: a cell's
/// brightness shows how that whole week went against the target the user set.
///
/// That also makes the graph say something the streak cannot. A streak reports
/// the present; the heatmap reports whether the weeks around it were good ones.
library;

import 'package:gym_streak/core/domain/calendar_date.dart';

/// Shading level for a day: 0 means untrained, 1–4 increasing brightness.
int heatmapLevelFor({
  required bool trained,
  required int workoutsThatWeek,
  required int weeklyTarget,
}) {
  if (!trained) return 0;

  // Nothing to be a fraction of. A trained day should still look trained.
  if (weeklyTarget <= 0) return 4;

  final ratio = workoutsThatWeek / weeklyTarget;
  if (ratio < 0.5) return 1;
  if (ratio < 0.8) return 2;
  if (ratio < 1.0) return 3;
  return 4;
}

/// The Monday beginning the week [date] falls in.
CalendarDate weekStartOf(CalendarDate date) =>
    date.addDays(-date.weekday.index);

/// How many workouts fall in each week, keyed by that week's Monday.
Map<CalendarDate, int> countWorkoutsPerWeek(Set<CalendarDate> workoutDays) {
  final counts = <CalendarDate, int>{};
  for (final day in workoutDays) {
    final start = weekStartOf(day);
    counts[start] = (counts[start] ?? 0) + 1;
  }
  return counts;
}
