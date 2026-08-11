import 'package:gym_streak/core/streak/streak_stats.dart';

/// Streak arithmetic over `yyyy-MM-dd` calendar dates.
///
/// Every comparison runs on integer *epoch day numbers* built through
/// [DateTime.utc], never on local-time [DateTime.difference]. That is not
/// stylistic: across a daylight-saving spring-forward two consecutive local
/// calendar dates are 23 hours apart, and `Duration(hours: 23).inDays` is 0, so
/// local-time subtraction silently severs an unbroken chain once a year. UTC has
/// no offset transitions, so epoch-day subtraction is always exact.
class StreakEngine {
  StreakEngine._();

  static const int _millisPerDay = 86400000;

  /// Reduces [dates] to a [StreakStats] as of [today].
  ///
  /// Unparseable entries and entries dated after [today] are ignored; duplicate
  /// dates collapse. [today] is read for its local calendar fields only.
  static StreakStats calculate({
    required Iterable<String> dates,
    required DateTime today,
  }) {
    final todayDay = epochDayOf(today);

    final days = <int>{};
    for (final raw in dates) {
      final day = tryEpochDayOf(raw);
      if (day == null) continue;
      if (day > todayDay) continue;
      days.add(day);
    }
    if (days.isEmpty) return StreakStats.empty;

    final sorted = days.toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    // A chain ending yesterday still counts: today is not over yet.
    var current = 0;
    if (todayDay - sorted.first <= 1) {
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

  /// The epoch day number of [dateTime]'s *calendar date*, ignoring its time
  /// and offset.
  static int epochDayOf(DateTime dateTime) =>
      DateTime.utc(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      ).millisecondsSinceEpoch ~/
      _millisPerDay;

  /// Parses a leading `yyyy-MM-dd` out of [isoDate], or null if there isn't one.
  ///
  /// Accepts a bare date or a full timestamp; only the first 10 characters are
  /// read.
  static int? tryEpochDayOf(String isoDate) {
    final trimmed = isoDate.trim();
    if (trimmed.length < 10) return null;
    final parsed = DateTime.tryParse('${trimmed.substring(0, 10)}T00:00:00Z');
    if (parsed == null) return null;
    return parsed.millisecondsSinceEpoch ~/ _millisPerDay;
  }
}
