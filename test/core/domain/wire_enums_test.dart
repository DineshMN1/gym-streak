import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/experience_level.dart';
import 'package:gym_streak/core/domain/fitness_goal.dart';
import 'package:gym_streak/core/domain/weekday.dart';
import 'package:gym_streak/core/domain/wire_enum.dart';
import 'package:gym_streak/core/domain/workout_type.dart';

/// Every domain enum stores a stable [WireEnum.wire] code and shows a separate
/// [WireEnum.label]. These tests exist to keep those two from collapsing back
/// into one string — the whole point is that a label can be reworded or
/// translated without rewriting rows in Postgres.
void main() {
  void behavesLikeAWireEnum<T extends WireEnum>(
    String name,
    List<T> values,
    T? Function(String) fromWire,
  ) {
    group(name, () {
      test('has values', () => expect(values, isNotEmpty));

      test('wire codes are unique', () {
        final wires = values.map((v) => v.wire).toList();
        expect(wires.toSet(), hasLength(wires.length));
      });

      test('wire codes are lowercase snake_case, never display labels', () {
        for (final v in values) {
          expect(
            v.wire,
            matches(RegExp(r'^[a-z][a-z0-9_]*$')),
            reason: '${v.wire} is not a storage-safe code',
          );
        }
      });

      test('labels are non-empty', () {
        for (final v in values) {
          expect(v.label, isNotEmpty, reason: 'no label for ${v.wire}');
        }
      });

      test('fromWire round-trips every value', () {
        for (final v in values) {
          expect(fromWire(v.wire), v);
        }
      });

      test('fromWire returns null for unknown codes', () {
        // A row written by a newer client must not crash an older one.
        expect(fromWire('not_a_real_value'), isNull);
        expect(fromWire(''), isNull);
      });

      test('fromWire does not accept the display label', () {
        // Guards the old behaviour, where the label WAS the stored value.
        expect(fromWire(values.first.label), isNull);
      });
    });
  }

  behavesLikeAWireEnum('WorkoutType', WorkoutType.values, WorkoutType.fromWire);
  behavesLikeAWireEnum('FitnessGoal', FitnessGoal.values, FitnessGoal.fromWire);
  behavesLikeAWireEnum(
    'ExperienceLevel',
    ExperienceLevel.values,
    ExperienceLevel.fromWire,
  );
  behavesLikeAWireEnum('Weekday', Weekday.values, Weekday.fromWire);

  group('wire codes are pinned', () {
    // These strings are the database contract. Changing one silently orphans
    // every stored row, so a rename must break this test loudly.
    test('WorkoutType', () {
      expect(WorkoutType.values.map((v) => v.wire), [
        'strength',
        'cardio',
        'hiit',
        'yoga',
        'calisthenics',
        'crossfit',
        'swimming',
        'running',
      ]);
    });

    test('FitnessGoal', () {
      expect(FitnessGoal.values.map((v) => v.wire), [
        'build_muscle',
        'lose_weight',
        'stay_fit',
        'increase_endurance',
        'flexibility',
        'gain_strength',
      ]);
    });

    test('ExperienceLevel', () {
      expect(ExperienceLevel.values.map((v) => v.wire), [
        'beginner',
        'intermediate',
        'advanced',
      ]);
    });

    test('Weekday', () {
      expect(Weekday.values.map((v) => v.wire), [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ]);
    });
  });

  group('labels match what the UI showed before the refactor', () {
    test('WorkoutType labels are unchanged', () {
      expect(WorkoutType.values.map((v) => v.label), [
        'Strength',
        'Cardio',
        'HIIT',
        'Yoga',
        'Calisthenics',
        'CrossFit',
        'Swimming',
        'Running',
      ]);
    });

    test('FitnessGoal labels are unchanged', () {
      expect(FitnessGoal.values.map((v) => v.label), [
        'Build Muscle',
        'Lose Weight',
        'Stay Fit',
        'Increase Endurance',
        'Flexibility',
        'Gain Strength',
      ]);
    });

    test('Weekday labels are the short forms the picker used', () {
      expect(Weekday.values.map((v) => v.label), [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ]);
    });
  });

  group('decodeWireList', () {
    test('decodes known codes and drops unknown ones', () {
      expect(
        decodeWireList(['strength', 'nope', 'yoga'], WorkoutType.fromWire),
        [WorkoutType.strength, WorkoutType.yoga],
      );
    });

    test('returns empty for an empty list', () {
      expect(decodeWireList([], WorkoutType.fromWire), isEmpty);
    });

    test('ignores non-string entries', () {
      expect(decodeWireList([1, null, 'cardio'], WorkoutType.fromWire), [
        WorkoutType.cardio,
      ]);
    });
  });
}
