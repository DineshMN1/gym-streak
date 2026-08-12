import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/core/domain/workout_type.dart';
import 'package:gym_streak/models/workout_log.dart';

void main() {
  Map<String, dynamic> row({
    String? id = 'row-1',
    String date = '2026-08-12',
    String workoutType = 'strength',
    String? completedAt = '2026-08-12T12:00:00.000Z',
  }) {
    return {
      'id': id,
      'date': date,
      'workout_type': workoutType,
      'completed_at': completedAt,
    };
  }

  group('WorkoutLog.fromMap', () {
    test('decodes a well-formed row', () {
      final log = WorkoutLog.fromMap(row())!;
      expect(log.id, 'row-1');
      expect(log.date, CalendarDate.tryParse('2026-08-12'));
      expect(log.workoutType, WorkoutType.strength);
      expect(log.completedAt, DateTime.parse('2026-08-12T12:00:00.000Z'));
    });

    test('keeps the row id so the row can be addressed later', () {
      // The old model dropped `id`, leaving delete/update to match on
      // (user_id, date) instead of the primary key.
      expect(WorkoutLog.fromMap(row(id: 'abc'))?.id, 'abc');
    });

    test('returns null when the date is missing or unparseable', () {
      // A row with no usable date cannot take part in streak arithmetic, so
      // there is nothing meaningful to construct.
      expect(WorkoutLog.fromMap(row(date: '')), isNull);
      expect(WorkoutLog.fromMap(row(date: 'garbage')), isNull);
    });

    test('returns null for an unknown workout type', () {
      // Written by a newer client; skip rather than crash.
      expect(WorkoutLog.fromMap(row(workoutType: 'quidditch')), isNull);
    });

    test('rejects a legacy display-label workout type', () {
      // Rows written before the wire/label split stored 'Strength'.
      expect(WorkoutLog.fromMap(row(workoutType: 'Strength')), isNull);
    });

    test('tolerates a missing completed_at', () {
      expect(
        WorkoutLog.fromMap(row(completedAt: null))?.completedAt,
        isNotNull,
      );
    });
  });

  group('WorkoutLog.toMap', () {
    test('writes wire codes, not display labels', () {
      final log = WorkoutLog(
        date: CalendarDate.tryParse('2026-08-12')!,
        workoutType: WorkoutType.crossfit,
        completedAt: DateTime.utc(2026, 8, 12, 12),
      );
      final map = log.toMap('user-1');

      expect(map['workout_type'], 'crossfit');
      expect(map['workout_type'], isNot('CrossFit'));
      expect(map['date'], '2026-08-12');
      expect(map['user_id'], 'user-1');
    });

    test('round-trips through fromMap', () {
      final original = WorkoutLog.fromMap(row())!;
      final restored = WorkoutLog.fromMap({
        ...original.toMap('user-1'),
        'id': original.id,
      });
      expect(restored, original);
    });

    test('omits the id so the database can assign one on insert', () {
      final log = WorkoutLog(
        date: CalendarDate.tryParse('2026-08-12')!,
        workoutType: WorkoutType.yoga,
        completedAt: DateTime.utc(2026, 8, 12),
      );
      expect(log.toMap('user-1').containsKey('id'), isFalse);
    });
  });

  group('WorkoutLog value semantics', () {
    test('identical content is equal and shares a hashCode', () {
      final a = WorkoutLog.fromMap(row())!;
      final b = WorkoutLog.fromMap(row())!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing content is not equal', () {
      final a = WorkoutLog.fromMap(row())!;
      expect(a, isNot(WorkoutLog.fromMap(row(date: '2026-08-11'))));
      expect(a, isNot(WorkoutLog.fromMap(row(workoutType: 'yoga'))));
    });

    test('equal logs collapse in a Set', () {
      // Without ==, every stream emission looks like new data and every
      // watching widget rebuilds.
      expect({
        WorkoutLog.fromMap(row())!,
        WorkoutLog.fromMap(row())!,
      }, hasLength(1));
    });
  });
}
