import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/workout_type.dart';
import 'package:gym_streak/features/home/data/pending_workout_queue.dart';
import 'package:gym_streak/models/workout_log.dart';

/// In-memory stand-in for shared_preferences.
class _FakeStore implements PendingWorkoutStore {
  List<String> _rows = const [];

  @override
  Future<List<String>> read() async => _rows;

  @override
  Future<void> write(List<String> rows) async => _rows = rows;
}

CalendarDate d(String iso) => CalendarDate.tryParse(iso)!;

void main() {
  late _FakeStore store;
  late PendingWorkoutQueue queue;

  setUp(() {
    store = _FakeStore();
    queue = PendingWorkoutQueue(store);
  });

  group('PendingWorkoutQueue', () {
    test('starts empty', () async {
      expect(await queue.pending(), isEmpty);
    });

    test('keeps what was enqueued', () async {
      await queue.enqueue(d('2026-08-12'), WorkoutType.strength);
      final pending = await queue.pending();
      expect(pending, hasLength(1));
      expect(pending.single.date, d('2026-08-12'));
      expect(pending.single.workoutType, WorkoutType.strength);
    });

    test('survives a new queue over the same store', () async {
      // Proves the data really round-trips through storage rather than
      // living in memory.
      await queue.enqueue(d('2026-08-12'), WorkoutType.yoga);
      final reopened = await PendingWorkoutQueue(store).pending();
      expect(reopened.single.workoutType, WorkoutType.yoga);
    });

    test('holds at most one entry per date', () async {
      // Mirrors the database's unique (user_id, date) constraint: logging
      // twice in a day is a correction, not a second workout.
      await queue.enqueue(d('2026-08-12'), WorkoutType.strength);
      await queue.enqueue(d('2026-08-12'), WorkoutType.cardio);
      final pending = await queue.pending();
      expect(pending, hasLength(1));
      expect(pending.single.workoutType, WorkoutType.cardio);
    });

    test('keeps separate dates apart', () async {
      await queue.enqueue(d('2026-08-12'), WorkoutType.strength);
      await queue.enqueue(d('2026-08-11'), WorkoutType.yoga);
      expect(await queue.pending(), hasLength(2));
    });

    test('removes a specific date once it has synced', () async {
      await queue.enqueue(d('2026-08-12'), WorkoutType.strength);
      await queue.enqueue(d('2026-08-11'), WorkoutType.yoga);
      await queue.remove(d('2026-08-12'));
      final pending = await queue.pending();
      expect(pending.single.date, d('2026-08-11'));
    });

    test('removing an absent date is harmless', () async {
      await queue.enqueue(d('2026-08-12'), WorkoutType.strength);
      await queue.remove(d('1999-01-01'));
      expect(await queue.pending(), hasLength(1));
    });

    test('discards corrupt rows instead of failing to load', () async {
      // A partially written or older-format entry must not make the whole
      // queue unreadable — that would strand every other pending workout.
      store._rows = ['not json at all', '{"date":"2026-08-12","type":"yoga"}'];
      final pending = await queue.pending();
      expect(pending.single.workoutType, WorkoutType.yoga);
    });

    test('discards rows naming an unknown workout type', () async {
      store._rows = ['{"date":"2026-08-12","type":"quidditch"}'];
      expect(await queue.pending(), isEmpty);
    });
  });

  group('mergePendingIntoLogs', () {
    WorkoutLog log(String iso, WorkoutType type) => WorkoutLog(
      date: d(iso),
      workoutType: type,
      completedAt: DateTime.utc(2026, 8, 12),
    );

    test('returns the remote logs when nothing is pending', () {
      final remote = [log('2026-08-12', WorkoutType.strength)];
      expect(mergePendingIntoLogs(remote, const []), remote);
    });

    test('adds a pending workout the server has not seen', () {
      final merged = mergePendingIntoLogs(
        [log('2026-08-11', WorkoutType.strength)],
        [PendingWorkout(date: d('2026-08-12'), workoutType: WorkoutType.yoga)],
      );
      expect(
        merged.map((l) => l.date.toIso()),
        containsAll(<String>['2026-08-11', '2026-08-12']),
      );
    });

    test('lets a pending workout win over a stale remote row', () {
      // The user corrected today's type while offline; the local edit is the
      // newer intent.
      final merged = mergePendingIntoLogs(
        [log('2026-08-12', WorkoutType.strength)],
        [PendingWorkout(date: d('2026-08-12'), workoutType: WorkoutType.yoga)],
      );
      expect(merged, hasLength(1));
      expect(merged.single.workoutType, WorkoutType.yoga);
    });

    test('is sorted newest first, matching the remote stream', () {
      final merged = mergePendingIntoLogs(
        [log('2026-08-10', WorkoutType.strength)],
        [
          PendingWorkout(date: d('2026-08-12'), workoutType: WorkoutType.yoga),
          PendingWorkout(
            date: d('2026-08-11'),
            workoutType: WorkoutType.cardio,
          ),
        ],
      );
      expect(merged.map((l) => l.date.toIso()).toList(), [
        '2026-08-12',
        '2026-08-11',
        '2026-08-10',
      ]);
    });
  });
}
