import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/weekday.dart';

void main() {
  group('CalendarDate.tryParse', () {
    test('accepts a bare yyyy-MM-dd date', () {
      expect(CalendarDate.tryParse('2026-08-12')?.toIso(), '2026-08-12');
    });

    test('accepts a full timestamp and keeps only the date part', () {
      expect(
        CalendarDate.tryParse('2026-08-12T23:45:01.000Z')?.toIso(),
        '2026-08-12',
      );
    });

    test('tolerates surrounding whitespace', () {
      expect(CalendarDate.tryParse('  2026-08-12  ')?.toIso(), '2026-08-12');
    });

    test('returns null for anything unparseable', () {
      expect(CalendarDate.tryParse(''), isNull);
      expect(CalendarDate.tryParse('garbage'), isNull);
      expect(CalendarDate.tryParse('not-a-date'), isNull);
      expect(CalendarDate.tryParse('2026-08'), isNull, reason: 'too short');
    });
  });

  group('CalendarDate.fromDateTime', () {
    test('reads local calendar fields, not the underlying instant', () {
      // 23:59 local is still the same calendar day, whatever the offset is.
      expect(
        CalendarDate.fromDateTime(DateTime(2026, 8, 12, 23, 59)).toIso(),
        '2026-08-12',
      );
    });

    test('agrees with tryParse for the same calendar day', () {
      expect(
        CalendarDate.fromDateTime(DateTime(2026, 8, 12, 6, 30)),
        CalendarDate.tryParse('2026-08-12'),
      );
    });
  });

  group('CalendarDate day arithmetic', () {
    test('consecutive days are exactly one apart across a spring-forward', () {
      // REGRESSION GUARD, inherited from StreakEngine. US spring-forward is
      // 2026-03-08 02:00, so those two local days are 23 hours apart and
      // Duration.inDays reads that as 0. Epoch-day subtraction must read 1.
      // Only exercised for real under TZ=America/Los_Angeles.
      final a = CalendarDate.tryParse('2026-03-08')!;
      final b = CalendarDate.tryParse('2026-03-09')!;
      expect(b.daysAfter(a), 1);
    });

    test('is exact across a fall-back too', () {
      final a = CalendarDate.tryParse('2026-11-01')!;
      final b = CalendarDate.tryParse('2026-11-02')!;
      expect(b.daysAfter(a), 1);
    });

    test('addDays moves forward and backward', () {
      final d = CalendarDate.tryParse('2026-08-12')!;
      expect(d.addDays(1).toIso(), '2026-08-13');
      expect(d.addDays(-1).toIso(), '2026-08-11');
      expect(d.addDays(0), d);
    });

    test('addDays crosses a month boundary', () {
      expect(
        CalendarDate.tryParse('2026-08-31')!.addDays(1).toIso(),
        '2026-09-01',
      );
    });

    test('addDays crosses a year boundary', () {
      expect(
        CalendarDate.tryParse('2026-12-31')!.addDays(1).toIso(),
        '2027-01-01',
      );
    });

    test('handles a leap day', () {
      expect(
        CalendarDate.tryParse('2028-02-28')!.addDays(1).toIso(),
        '2028-02-29',
      );
    });

    test('daysAfter is negative when the argument is later', () {
      final earlier = CalendarDate.tryParse('2026-08-10')!;
      final later = CalendarDate.tryParse('2026-08-12')!;
      expect(earlier.daysAfter(later), -2);
    });

    test('round-trips dates before the epoch', () {
      expect(CalendarDate.tryParse('1969-12-31')?.toIso(), '1969-12-31');
    });
  });

  group('CalendarDate.weekday', () {
    test('maps known dates to the right day', () {
      // 2026-08-12 is a Wednesday; the rest walk forward from it.
      expect(CalendarDate.tryParse('2026-08-10')!.weekday, Weekday.monday);
      expect(CalendarDate.tryParse('2026-08-11')!.weekday, Weekday.tuesday);
      expect(CalendarDate.tryParse('2026-08-12')!.weekday, Weekday.wednesday);
      expect(CalendarDate.tryParse('2026-08-13')!.weekday, Weekday.thursday);
      expect(CalendarDate.tryParse('2026-08-14')!.weekday, Weekday.friday);
      expect(CalendarDate.tryParse('2026-08-15')!.weekday, Weekday.saturday);
      expect(CalendarDate.tryParse('2026-08-16')!.weekday, Weekday.sunday);
    });

    test('is right at the epoch, which was a Thursday', () {
      expect(CalendarDate.tryParse('1970-01-01')!.weekday, Weekday.thursday);
    });

    test('is right before the epoch, where naive modulo goes negative', () {
      // 1969-12-29 was a Monday. Epoch day is negative here, so a plain
      // `% 7` would yield a negative index and crash.
      expect(CalendarDate.tryParse('1969-12-29')!.weekday, Weekday.monday);
      expect(CalendarDate.tryParse('1969-12-31')!.weekday, Weekday.wednesday);
    });

    test('agrees with DateTime.weekday', () {
      for (var i = 0; i < 14; i++) {
        final dt = DateTime(2026, 8, 1).add(Duration(days: i));
        final expected = Weekday.values[dt.weekday - 1]; // DateTime: 1 = Monday
        expect(CalendarDate.fromDateTime(dt).weekday, expected);
      }
    });
  });

  group('CalendarDate.today', () {
    test('uses the supplied clock', () {
      expect(
        CalendarDate.today(now: DateTime(2026, 8, 12, 4, 0)).toIso(),
        '2026-08-12',
      );
    });
  });

  group('CalendarDate value semantics', () {
    test('equal dates are equal and share a hashCode', () {
      final a = CalendarDate.tryParse('2026-08-12')!;
      final b = CalendarDate.tryParse('2026-08-12T09:00:00Z')!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different dates are not equal', () {
      expect(
        CalendarDate.tryParse('2026-08-12'),
        isNot(CalendarDate.tryParse('2026-08-13')),
      );
    });

    test('sorts chronologically', () {
      final dates = [
        CalendarDate.tryParse('2026-08-12')!,
        CalendarDate.tryParse('2026-08-10')!,
        CalendarDate.tryParse('2026-08-11')!,
      ]..sort();
      expect(dates.map((d) => d.toIso()).toList(), [
        '2026-08-10',
        '2026-08-11',
        '2026-08-12',
      ]);
    });

    test('deduplicates in a Set', () {
      final set = {
        CalendarDate.tryParse('2026-08-12')!,
        CalendarDate.tryParse('2026-08-12')!,
        CalendarDate.tryParse('2026-08-13')!,
      };
      expect(set, hasLength(2));
    });

    test('toString shows the ISO date', () {
      expect(
        CalendarDate.tryParse('2026-08-12').toString(),
        contains('2026-08-12'),
      );
    });
  });
}
