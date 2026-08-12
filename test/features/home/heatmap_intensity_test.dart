import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/features/home/heatmap_intensity.dart';

CalendarDate d(String iso) => CalendarDate.tryParse(iso)!;

void main() {
  group('heatmapLevelFor', () {
    test('a day with no workout is empty', () {
      expect(
        heatmapLevelFor(trained: false, workoutsThatWeek: 5, weeklyTarget: 3),
        0,
      );
    });

    test('rises with progress towards the target', () {
      int level(int done) => heatmapLevelFor(
        trained: true,
        workoutsThatWeek: done,
        weeklyTarget: 4,
      );
      expect(level(1), 1, reason: 'a quarter of the way');
      expect(level(2), 2, reason: 'halfway');
      expect(level(4), 4, reason: 'target met');
    });

    test('meeting the target is the brightest ordinary level', () {
      expect(
        heatmapLevelFor(trained: true, workoutsThatWeek: 3, weeklyTarget: 3),
        4,
      );
    });

    test('beating the target does not overflow the scale', () {
      expect(
        heatmapLevelFor(trained: true, workoutsThatWeek: 9, weeklyTarget: 3),
        4,
      );
    });

    test('falls back to full brightness when no target is set', () {
      // Without a target there is nothing to be a fraction of, so a trained
      // day should look trained rather than dim.
      expect(
        heatmapLevelFor(trained: true, workoutsThatWeek: 1, weeklyTarget: 0),
        4,
      );
    });

    test('never returns a level outside 0..4', () {
      for (var target = 0; target <= 7; target++) {
        for (var done = 0; done <= 10; done++) {
          final level = heatmapLevelFor(
            trained: true,
            workoutsThatWeek: done,
            weeklyTarget: target,
          );
          expect(level, inInclusiveRange(0, 4));
        }
      }
    });
  });

  group('weekStartOf', () {
    test('is the Monday of that week', () {
      // 2026-08-12 is a Wednesday.
      expect(weekStartOf(d('2026-08-12')), d('2026-08-10'));
    });

    test('a Monday is its own week start', () {
      expect(weekStartOf(d('2026-08-10')), d('2026-08-10'));
    });

    test('a Sunday belongs to the week that began six days earlier', () {
      expect(weekStartOf(d('2026-08-16')), d('2026-08-10'));
    });

    test('crosses a month boundary', () {
      // 2026-09-01 is a Tuesday, so its week began in August.
      expect(weekStartOf(d('2026-09-01')), d('2026-08-31'));
    });
  });

  group('countWorkoutsPerWeek', () {
    test('groups days into their weeks', () {
      final counts = countWorkoutsPerWeek({
        d('2026-08-10'), // Mon
        d('2026-08-12'), // Wed
        d('2026-08-17'), // Mon, next week
      });
      expect(counts[d('2026-08-10')], 2);
      expect(counts[d('2026-08-17')], 1);
    });

    test('is empty for no workouts', () {
      expect(countWorkoutsPerWeek(const {}), isEmpty);
    });
  });
}
