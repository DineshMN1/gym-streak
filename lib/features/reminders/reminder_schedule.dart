import 'package:gym_streak/core/domain/weekday.dart';

/// Default reminder time: early evening, after work and before the gym closes.
const int defaultReminderHour = 18;

/// The next moment [weekday] falls at [hour]:[minute], strictly after [from].
///
/// Strictly, not "at or after": scheduling for exactly now fires immediately
/// and then leaves the weekly repeat anchored to the wrong instant.
///
/// Pure so the awkward cases — the time already gone today, an earlier weekday
/// wrapping into next week, a month boundary — can be tested without a device.
DateTime nextOccurrence({
  required DateTime from,
  required Weekday weekday,
  required int hour,
  int minute = 0,
}) {
  // DateTime.weekday is 1 = Monday, matching the order of Weekday.values.
  final targetIndex = weekday.index + 1;
  var daysAhead = (targetIndex - from.weekday) % 7;
  if (daysAhead < 0) daysAhead += 7;

  var candidate = DateTime(
    from.year,
    from.month,
    from.day + daysAhead,
    hour,
    minute,
  );
  if (!candidate.isAfter(from)) {
    candidate = DateTime(
      from.year,
      from.month,
      from.day + daysAhead + 7,
      hour,
      minute,
    );
  }
  return candidate;
}

/// Which days to remind on, given the user's training plan.
///
/// An empty plan means remind daily rather than never — someone who skipped
/// that onboarding step still wants nudging, and reminding on no days would
/// silently disable the feature for them.
Set<Weekday> reminderDaysFor(Set<Weekday> scheduledDays) =>
    scheduledDays.isEmpty ? Weekday.values.toSet() : scheduledDays;

/// A stable notification id per weekday.
///
/// Stability matters because cancelling recomputes the id rather than storing
/// it; a scheme derived from anything mutable would orphan old notifications.
int reminderIdFor(Weekday weekday) => 1000 + weekday.index;
