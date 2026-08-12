import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/weekday.dart';
import 'package:gym_streak/features/reminders/reminder_schedule.dart';

void main() {
  group('nextOccurrence', () {
    // 2026-08-12 is a Wednesday.
    final wedMorning = DateTime(2026, 8, 12, 9, 0);

    test('is later the same day when the time has not passed', () {
      expect(
        nextOccurrence(from: wedMorning, weekday: Weekday.wednesday, hour: 18),
        DateTime(2026, 8, 12, 18, 0),
      );
    });

    test('rolls to next week when today is already past the time', () {
      final wedEvening = DateTime(2026, 8, 12, 19, 30);
      expect(
        nextOccurrence(from: wedEvening, weekday: Weekday.wednesday, hour: 18),
        DateTime(2026, 8, 19, 18, 0),
      );
    });

    test('finds a later day in the same week', () {
      expect(
        nextOccurrence(from: wedMorning, weekday: Weekday.friday, hour: 18),
        DateTime(2026, 8, 14, 18, 0),
      );
    });

    test('wraps to the following week for an earlier weekday', () {
      expect(
        nextOccurrence(from: wedMorning, weekday: Weekday.monday, hour: 18),
        DateTime(2026, 8, 17, 18, 0),
      );
    });

    test('is always strictly in the future', () {
      // Exactly on the boundary: scheduling for "now" would fire instantly
      // and then never repeat correctly.
      final exactly = DateTime(2026, 8, 12, 18, 0);
      expect(
        nextOccurrence(from: exactly, weekday: Weekday.wednesday, hour: 18),
        DateTime(2026, 8, 19, 18, 0),
      );
    });

    test('honours the minute', () {
      expect(
        nextOccurrence(
          from: wedMorning,
          weekday: Weekday.wednesday,
          hour: 18,
          minute: 45,
        ),
        DateTime(2026, 8, 12, 18, 45),
      );
    });

    test('crosses a month boundary', () {
      expect(
        nextOccurrence(
          from: DateTime(2026, 8, 31, 9, 0), // a Monday
          weekday: Weekday.tuesday,
          hour: 18,
        ),
        DateTime(2026, 9, 1, 18, 0),
      );
    });
  });

  group('reminderDaysFor', () {
    test('uses the training plan when there is one', () {
      expect(
        reminderDaysFor({Weekday.monday, Weekday.thursday}),
        {Weekday.monday, Weekday.thursday},
      );
    });

    test('falls back to every day when no plan was chosen', () {
      // Someone who skipped that onboarding step still wants reminding;
      // reminding on nothing would silently disable the feature.
      expect(reminderDaysFor(const {}), Weekday.values.toSet());
    });
  });

  group('notification ids', () {
    test('each weekday gets a distinct, stable id', () {
      final ids = Weekday.values.map(reminderIdFor).toList();
      expect(ids.toSet(), hasLength(Weekday.values.length));
      // Stable across runs: cancelling relies on recomputing the same id.
      expect(reminderIdFor(Weekday.monday), reminderIdFor(Weekday.monday));
    });
  });
}
