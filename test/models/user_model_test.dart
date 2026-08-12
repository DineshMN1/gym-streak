import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/experience_level.dart';
import 'package:gym_streak/core/domain/fitness_goal.dart';
import 'package:gym_streak/core/domain/weekday.dart';
import 'package:gym_streak/core/domain/workout_type.dart';
import 'package:gym_streak/models/user_model.dart';

void main() {
  Map<String, dynamic> row({
    String id = 'user-1',
    String name = 'Dinesh',
    String email = 'd@example.com',
    String experienceLevel = 'intermediate',
    List<dynamic> workoutTypes = const ['strength', 'yoga'],
    List<dynamic> fitnessGoals = const ['build_muscle'],
    List<dynamic> preferredDays = const ['monday', 'wednesday'],
    int workoutsPerWeek = 4,
    bool onboardingComplete = true,
  }) {
    return {
      'id': id,
      'name': name,
      'email': email,
      'experience_level': experienceLevel,
      'workout_types': workoutTypes,
      'fitness_goals': fitnessGoals,
      'preferred_days': preferredDays,
      'workouts_per_week': workoutsPerWeek,
      'onboarding_complete': onboardingComplete,
      'created_at': '2026-08-01T00:00:00.000Z',
    };
  }

  group('UserModel.fromMap', () {
    test('decodes wire codes into typed values', () {
      final user = UserModel.fromMap(row());
      expect(user.uid, 'user-1');
      expect(user.experienceLevel, ExperienceLevel.intermediate);
      expect(user.workoutTypes, [WorkoutType.strength, WorkoutType.yoga]);
      expect(user.fitnessGoals, [FitnessGoal.buildMuscle]);
      expect(user.preferredDays, [Weekday.monday, Weekday.wednesday]);
      expect(user.workoutsPerWeek, 4);
      expect(user.onboardingComplete, isTrue);
    });

    test('drops unknown codes instead of throwing', () {
      final user = UserModel.fromMap(
        row(workoutTypes: ['strength', 'quidditch', 'yoga']),
      );
      expect(user.workoutTypes, [WorkoutType.strength, WorkoutType.yoga]);
    });

    test('drops legacy display labels', () {
      // Rows written before the wire/label split held 'Build Muscle'.
      final user = UserModel.fromMap(
        row(fitnessGoals: ['Build Muscle', 'lose_weight']),
      );
      expect(user.fitnessGoals, [FitnessGoal.loseWeight]);
    });

    test('leaves experienceLevel null when it is absent or unknown', () {
      expect(
        UserModel.fromMap(row(experienceLevel: '')).experienceLevel,
        isNull,
      );
      expect(
        UserModel.fromMap(row(experienceLevel: 'Beginner')).experienceLevel,
        isNull,
        reason: 'legacy display label',
      );
    });

    test('falls back sensibly on a sparse row', () {
      final user = UserModel.fromMap({'id': 'u'});
      expect(user.uid, 'u');
      expect(user.name, '');
      expect(user.workoutTypes, isEmpty);
      expect(user.workoutsPerWeek, 3);
      expect(user.onboardingComplete, isFalse);
    });
  });

  group('UserModel.toMap', () {
    test('writes wire codes, not display labels', () {
      final map = UserModel.fromMap(row()).toMap();
      expect(map['experience_level'], 'intermediate');
      expect(map['workout_types'], ['strength', 'yoga']);
      expect(map['fitness_goals'], ['build_muscle']);
      expect(map['preferred_days'], ['monday', 'wednesday']);
    });

    test('writes an empty string for a null experience level', () {
      final map = UserModel.fromMap(row(experienceLevel: '')).toMap();
      expect(map['experience_level'], '');
    });

    test('round-trips through fromMap', () {
      final original = UserModel.fromMap(row());
      expect(UserModel.fromMap(original.toMap()), original);
    });
  });

  group('UserModel value semantics', () {
    test('identical content is equal and shares a hashCode', () {
      final a = UserModel.fromMap(row());
      final b = UserModel.fromMap(row());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('compares list contents, not list identity', () {
      // Two separately-decoded rows hold different List instances; without
      // deep equality every profile stream emission would look like a change.
      final a = UserModel.fromMap(row(workoutTypes: ['strength', 'yoga']));
      final b = UserModel.fromMap(row(workoutTypes: ['strength', 'yoga']));
      expect(identical(a.workoutTypes, b.workoutTypes), isFalse);
      expect(a, b);
    });

    test('differing list contents are not equal', () {
      expect(
        UserModel.fromMap(row(workoutTypes: ['strength'])),
        isNot(UserModel.fromMap(row(workoutTypes: ['yoga']))),
      );
    });

    test('differing scalars are not equal', () {
      expect(
        UserModel.fromMap(row(name: 'A')),
        isNot(UserModel.fromMap(row(name: 'B'))),
      );
    });
  });

  group('UserModel.copyWith', () {
    test('replaces only what it is given', () {
      final user = UserModel.fromMap(row());
      final updated = user.copyWith(name: 'New Name');
      expect(updated.name, 'New Name');
      expect(updated.workoutTypes, user.workoutTypes);
      expect(updated.uid, user.uid);
    });
  });
}
