import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/weekday.dart';
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
  ///
  /// [scheduledDays] is the user's training plan. When it is non-empty, only
  /// those weekdays can break a streak — resting on an unscheduled day is
  /// adherence, not failure. That distinction is the whole point: a user who
  /// tells the app "Mon/Wed/Fri" and then rests on Tuesday is doing exactly
  /// what they planned, and counting it as a break punishes them for it.
  ///
  /// An empty set means "every day counts", which is both the original
  /// behaviour and the right fallback for anyone who has not finished
  /// onboarding.
  static StreakStats calculate({
    required Iterable<CalendarDate> dates,
    required CalendarDate today,
    Set<Weekday> scheduledDays = const {},
  }) {
    final trained = <int>{};
    for (final date in dates) {
      if (date.daysAfter(today) > 0) continue;
      trained.add(date.epochDay);
    }
    if (trained.isEmpty) return StreakStats.empty;

    // `total` counts every distinct day the user showed up, scheduled or not —
    // an extra session is still a session.
    final total = trained.length;

    final planned = scheduledDays.isEmpty
        ? Weekday.values.toSet()
        : scheduledDays;
    final everyDayCounts = planned.length == Weekday.values.length;

    bool isScheduled(int epochDay) =>
        everyDayCounts ||
        planned.contains(CalendarDate.fromEpochDay(epochDay).weekday);

    final oldest = trained.reduce((a, b) => a < b ? a : b);

    // Walk back one day at a time from today to the earliest day on record. A
    // day is fine if it was trained or was never scheduled; the first missed
    // scheduled day ends the run.
    //
    // Today itself is exempt even when scheduled: the day is not over, and
    // judging it now would break the streak of everyone who trains in the
    // evening.
    //
    // The count is of days *trained*, so an extra session on a rest day adds to
    // the streak rather than merely not breaking it. That keeps the number
    // honest against its "day streak" label.
    var current = 0;
    for (var day = today.epochDay - 1; day >= oldest; day--) {
      if (trained.contains(day)) {
        current++;
      } else if (isScheduled(day)) {
        break;
      }
    }
    if (trained.contains(today.epochDay)) current++;

    // `best` is the longest such run anywhere in the history, measured the same
    // way: a gap only breaks it if a scheduled day was missed.
    var best = 0;
    var run = 0;
    for (var day = oldest; day <= today.epochDay; day++) {
      if (trained.contains(day)) {
        run++;
        if (run > best) best = run;
      } else if (isScheduled(day)) {
        run = 0;
      }
    }

    return StreakStats(current: current, best: best, total: total);
  }
}
