import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/streak/streak_engine.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';

void main() {
  // A fixed "today" keeps every case deterministic.
  final today = DateTime(2026, 8, 12);

  StreakStats calc(List<String> dates) =>
      StreakEngine.calculate(dates: dates, today: today);

  group('StreakEngine.calculate', () {
    test('returns empty for no dates', () {
      expect(calc([]), StreakStats.empty);
    });

    test('a single log today is a streak of one', () {
      expect(
        calc(['2026-08-12']),
        const StreakStats(current: 1, best: 1, total: 1),
      );
    });

    test('counts an unbroken chain ending today', () {
      expect(
        calc(['2026-08-12', '2026-08-11', '2026-08-10']),
        const StreakStats(current: 3, best: 3, total: 3),
      );
    });

    test('a chain ending yesterday is still current', () {
      // The day is not over yet; not logging today has not broken anything.
      expect(
        calc(['2026-08-11', '2026-08-10']),
        const StreakStats(current: 2, best: 2, total: 2),
      );
    });

    test('a chain ending two days ago is broken but still the best', () {
      expect(
        calc(['2026-08-10', '2026-08-09']),
        const StreakStats(current: 0, best: 2, total: 2),
      );
    });

    test('handles unsorted input', () {
      expect(
        calc(['2026-08-10', '2026-08-12', '2026-08-11']),
        const StreakStats(current: 3, best: 3, total: 3),
      );
    });

    test('collapses duplicate dates', () {
      expect(
        calc(['2026-08-12', '2026-08-12', '2026-08-11']),
        const StreakStats(current: 2, best: 2, total: 2),
      );
    });

    test('best is the longest run, current is only the trailing run', () {
      // A 4-day run in July, then a 2-day run ending today.
      expect(
        calc([
          '2026-07-01',
          '2026-07-02',
          '2026-07-03',
          '2026-07-04',
          '2026-08-11',
          '2026-08-12',
        ]),
        const StreakStats(current: 2, best: 4, total: 6),
      );
    });

    test('ignores future-dated rows', () {
      expect(
        calc(['2026-08-13', '2026-08-12', '2026-08-11']),
        const StreakStats(current: 2, best: 2, total: 2),
      );
    });

    test('ignores unparseable rows', () {
      expect(
        calc(['not-a-date', 'garbage', '', '2026-08-12']),
        const StreakStats(current: 1, best: 1, total: 1),
      );
    });

    test('accepts full timestamps as well as bare dates', () {
      expect(
        calc(['2026-08-12T10:30:00', '2026-08-11']),
        const StreakStats(current: 2, best: 2, total: 2),
      );
    });

    test('survives a daylight-saving spring-forward', () {
      // REGRESSION GUARD. US spring-forward is 2026-03-08 02:00, so the
      // 08->09 gap is 23 local hours. The previous implementation used
      // local DateTime.difference().inDays, read that as 0, and reported 2.
      // Run this file under TZ=America/Los_Angeles to exercise it for real.
      final stats = StreakEngine.calculate(
        dates: ['2026-03-08', '2026-03-09', '2026-03-10'],
        today: DateTime(2026, 3, 10),
      );
      expect(stats, const StreakStats(current: 3, best: 3, total: 3));
    });

    test('survives a daylight-saving fall-back', () {
      final stats = StreakEngine.calculate(
        dates: ['2026-11-01', '2026-11-02', '2026-11-03'],
        today: DateTime(2026, 11, 3),
      );
      expect(stats, const StreakStats(current: 3, best: 3, total: 3));
    });
  });

  group('StreakEngine day arithmetic', () {
    test('consecutive dates are exactly one epoch day apart across DST', () {
      expect(
        StreakEngine.tryEpochDayOf('2026-03-09')! -
            StreakEngine.tryEpochDayOf('2026-03-08')!,
        1,
      );
    });

    test('tryEpochDayOf rejects junk', () {
      expect(StreakEngine.tryEpochDayOf(''), isNull);
      expect(StreakEngine.tryEpochDayOf('garbage'), isNull);
      expect(StreakEngine.tryEpochDayOf('not-a-date'), isNull);
    });

    test('epochDayOf uses local calendar fields, not the instant', () {
      expect(
        StreakEngine.epochDayOf(DateTime(2026, 8, 12, 23, 59)),
        StreakEngine.tryEpochDayOf('2026-08-12'),
      );
    });
  });

  group('StreakStats', () {
    test('values with the same fields are equal', () {
      expect(
        const StreakStats(current: 1, best: 2, total: 3),
        const StreakStats(current: 1, best: 2, total: 3),
      );
      expect(
        const StreakStats(current: 1, best: 2, total: 3).hashCode,
        const StreakStats(current: 1, best: 2, total: 3).hashCode,
      );
    });

    test('empty is all zeroes', () {
      expect(
        StreakStats.empty,
        const StreakStats(current: 0, best: 0, total: 0),
      );
    });
  });
}
