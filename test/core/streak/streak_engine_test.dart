import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/weekday.dart';
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

  group('StreakEngine.calculate with a training plan', () {
    // 2026-08-12 is a Wednesday. A Mon/Wed/Fri plan is the common case.
    const monWedFri = {Weekday.monday, Weekday.wednesday, Weekday.friday};

    StreakStats planned(List<String> dates, {CalendarDate? asOf}) =>
        StreakEngine.calculate(
          dates: dates.map(d),
          today: asOf ?? today,
          scheduledDays: monWedFri,
        );

    test('a planned rest day does not break the streak', () {
      // THE BUG THIS FEATURE EXISTS TO FIX. Trained Mon and Wed, rested
      // Tuesday exactly as planned. The old rule called that a broken streak
      // and reset the user to zero for following their own schedule.
      expect(planned(['2026-08-10', '2026-08-12']).current, 2);
    });

    test('a missed scheduled day does break it', () {
      // Trained Fri 7th and Wed 12th, skipped Mon 10th.
      expect(planned(['2026-08-07', '2026-08-12']).current, 1);
    });

    test('counts a full week of adherence', () {
      // Mon 3, Wed 5, Fri 7, Mon 10, Wed 12 — five scheduled sessions.
      expect(
        planned([
          '2026-08-03',
          '2026-08-05',
          '2026-08-07',
          '2026-08-10',
          '2026-08-12',
        ]).current,
        5,
      );
    });

    test('an extra session on a rest day adds to the streak', () {
      // Mon, Tue, Wed with a Mon/Wed/Fri plan. The Tuesday session is not
      // scheduled, but the user did train — and the number is labelled "day
      // streak", so counting three days is the honest answer. Counting only
      // scheduled days would show 2 and quietly punish the extra effort.
      expect(planned(['2026-08-10', '2026-08-11', '2026-08-12']).current, 3);
    });

    test('today being scheduled but unlogged is not yet a miss', () {
      // Wednesday is not over. Judging it now would break the streak of
      // anyone who trains in the evening.
      expect(planned(['2026-08-10']).current, 1);
    });

    test('a scheduled day missed yesterday does break it', () {
      // As of Thursday, Wednesday is genuinely missed.
      expect(planned(['2026-08-10'], asOf: d('2026-08-13')).current, 0);
    });

    test('best is the longest run of kept scheduled days', () {
      expect(
        planned([
          // July: Mon 6, Wed 8, Fri 10, Mon 13 — four in a row.
          '2026-07-06', '2026-07-08', '2026-07-10', '2026-07-13',
          // then a gap, then Wed 12 August.
          '2026-08-12',
        ]).best,
        4,
      );
    });

    test('total still counts every distinct day trained', () {
      // Including the unscheduled Tuesday — the user did show up.
      expect(planned(['2026-08-10', '2026-08-11', '2026-08-12']).total, 3);
    });

    test('an empty plan falls back to counting every day', () {
      // Users who never completed onboarding keep the original behaviour.
      expect(
        StreakEngine.calculate(
          dates: ['2026-08-12', '2026-08-11'].map(d),
          today: today,
          scheduledDays: const {},
        ),
        const StreakStats(current: 2, best: 2, total: 2),
      );
    });

    test('a seven-day plan behaves exactly like no plan', () {
      expect(
        StreakEngine.calculate(
          dates: ['2026-08-12', '2026-08-11'].map(d),
          today: today,
          scheduledDays: Weekday.values.toSet(),
        ),
        const StreakStats(current: 2, best: 2, total: 2),
      );
    });

    test('survives a spring-forward with a plan', () {
      // 2026-03-08 is a Sunday; Mon 9 and Wed 11 are the scheduled days
      // either side of the US clock change.
      expect(
        StreakEngine.calculate(
          dates: ['2026-03-09', '2026-03-11'].map(d),
          today: d('2026-03-11'),
          scheduledDays: monWedFri,
        ).current,
        2,
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
