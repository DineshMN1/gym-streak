import 'package:gym_streak/core/domain/weekday.dart';

/// A calendar day — no time, no timezone.
///
/// This is what a Postgres `date` column holds and what "the day a workout was
/// logged" actually means. Modelling it as a [DateTime] invites the bug this
/// type exists to prevent: across a daylight-saving spring-forward two adjacent
/// local days are 23 hours apart, and `Duration(hours: 23).inDays` is `0`, so
/// local-time subtraction silently severs a streak once a year.
///
/// Every instance is stored as an integer *epoch day* — days since
/// 1970-01-01 — derived through [DateTime.utc], which has no offset
/// transitions. Subtraction is therefore always exact.
///
/// Deliberately free of Flutter and Supabase imports so it stays testable as
/// plain Dart.
class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate._(this.epochDay);

  /// Days since 1970-01-01. Negative for earlier dates.
  final int epochDay;

  static const int _millisPerDay = 86400000;

  /// The calendar day [dateTime] falls on, read from its *local* year, month
  /// and day. The time of day and the offset are discarded.
  factory CalendarDate.fromDateTime(DateTime dateTime) {
    return CalendarDate._(
      DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
          ).millisecondsSinceEpoch ~/
          _millisPerDay,
    );
  }

  /// The day [epochDay] days after 1970-01-01.
  const factory CalendarDate.fromEpochDay(int epochDay) = CalendarDate._;

  /// Today's calendar day. Pass [now] to make callers deterministic in tests.
  factory CalendarDate.today({DateTime? now}) =>
      CalendarDate.fromDateTime(now ?? DateTime.now());

  /// Parses a leading `yyyy-MM-dd`, or returns null when there isn't one.
  ///
  /// Accepts a bare date or a full timestamp — only the first 10 characters are
  /// read, so `2026-08-12T23:45:01Z` and `2026-08-12` give the same day
  /// regardless of the time or offset that follows.
  static CalendarDate? tryParse(String iso) {
    final trimmed = iso.trim();
    if (trimmed.length < 10) return null;
    final parsed = DateTime.tryParse('${trimmed.substring(0, 10)}T00:00:00Z');
    if (parsed == null) return null;
    return CalendarDate._(parsed.millisecondsSinceEpoch ~/ _millisPerDay);
  }

  /// This day as `yyyy-MM-dd` — the format Postgres and PostgREST exchange.
  String toIso() {
    final d = DateTime.fromMillisecondsSinceEpoch(
      epochDay * _millisPerDay,
      isUtc: true,
    );
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Which day of the week this falls on.
  ///
  /// Epoch day 0 — 1970-01-01 — was a Thursday, so Monday sits at offset 3.
  /// The extra `+ 7` before the second modulo keeps pre-epoch dates, whose
  /// epoch day is negative, from producing a negative index.
  Weekday get weekday => Weekday.values[((epochDay + 3) % 7 + 7) % 7];

  /// The day [days] after this one; pass a negative value to go backwards.
  CalendarDate addDays(int days) => CalendarDate._(epochDay + days);

  /// How many days this day falls after [other]. Negative when [other] is later.
  int daysAfter(CalendarDate other) => epochDay - other.epochDay;

  @override
  int compareTo(CalendarDate other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarDate && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  @override
  String toString() => 'CalendarDate(${toIso()})';
}
