import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';

/// Streak arithmetic over calendar days.
///
/// All comparisons run on [CalendarDate], whose epoch-day representation is
/// exact across daylight-saving transitions. Parsing and validation happen
/// before this point — in `WorkoutLog.fromMap` — so the engine only ever sees
/// days it can trust and stays free of string handling.
class StreakEngine {
  StreakEngine._();

  /// Reduces [dates] to a [StreakStats] as of [today].
  ///
  /// Days after [today] are ignored; duplicates collapse.
  static StreakStats calculate({
    required Iterable<CalendarDate> dates,
    required CalendarDate today,
  }) {
    final days = <int>{};
    for (final date in dates) {
      if (date.daysAfter(today) > 0) continue;
      days.add(date.epochDay);
    }
    if (days.isEmpty) return StreakStats.empty;

    final sorted = days.toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    // A chain ending yesterday still counts: today is not over yet.
    var current = 0;
    if (today.epochDay - sorted.first <= 1) {
      current = 1;
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i - 1] - sorted[i] != 1) break;
        current++;
      }
    }

    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      run = (sorted[i - 1] - sorted[i] == 1) ? run + 1 : 1;
      if (run > best) best = run;
    }

    return StreakStats(current: current, best: best, total: sorted.length);
  }
}
