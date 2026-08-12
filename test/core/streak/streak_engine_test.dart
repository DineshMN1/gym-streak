import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/streak/streak_engine.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';

CalendarDate d(String iso) => CalendarDate.tryParse(iso)!;

void main() {
  // A fixed "today" keeps every case deterministic.
  final today = d('2026-08-12');

  StreakStats calc(List<String> dates) =>
      StreakEngine.calculate(dates: dates.map(d), today: today);

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

    test('survives a daylight-saving spring-forward', () {
      // REGRESSION GUARD. US spring-forward is 2026-03-08 02:00, so the
      // 08->09 gap is 23 local hours. An implementation using local
      // DateTime.difference().inDays reads that as 0 and reports 2.
      // Run under TZ=America/Los_Angeles to exercise it for real.
      expect(
        StreakEngine.calculate(
          dates: ['2026-03-08', '2026-03-09', '2026-03-10'].map(d),
          today: d('2026-03-10'),
        ),
        const StreakStats(current: 3, best: 3, total: 3),
      );
    });

    test('survives a daylight-saving fall-back', () {
      expect(
        StreakEngine.calculate(
          dates: ['2026-11-01', '2026-11-02', '2026-11-03'].map(d),
          today: d('2026-11-03'),
        ),
        const StreakStats(current: 3, best: 3, total: 3),
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

    test('differing fields are not equal', () {
      expect(
        const StreakStats(current: 1, best: 2, total: 3),
        isNot(const StreakStats(current: 9, best: 2, total: 3)),
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
