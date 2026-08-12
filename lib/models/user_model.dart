import 'package:flutter/foundation.dart' show listEquals;
import 'package:gym_streak/core/domain/experience_level.dart';
import 'package:gym_streak/core/domain/fitness_goal.dart';
import 'package:gym_streak/core/domain/weekday.dart';
import 'package:gym_streak/core/domain/wire_enum.dart';
import 'package:gym_streak/core/domain/workout_type.dart';

/// A user's profile row.
class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.experienceLevel,
    this.workoutTypes = const [],
    this.fitnessGoals = const [],
    this.preferredDays = const [],
    this.workoutsPerWeek = 3,
    this.onboardingComplete = false,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;

  /// Null until onboarding records one, or when the stored code is unknown.
  final ExperienceLevel? experienceLevel;

  final List<WorkoutType> workoutTypes;
  final List<FitnessGoal> fitnessGoals;
  final List<Weekday> preferredDays;
  final int workoutsPerWeek;
  final bool onboardingComplete;
  final DateTime createdAt;

  /// Decodes a PostgREST row.
  ///
  /// Unknown codes in the list columns are dropped rather than treated as
  /// errors — a profile is still usable when one preference cannot be read.
  factory UserModel.fromMap(Map<String, dynamic> data) {
    final createdAtRaw = data['created_at'];
    return UserModel(
      uid: '${data['id'] ?? ''}',
      name: '${data['name'] ?? ''}',
      email: '${data['email'] ?? ''}',
      experienceLevel: ExperienceLevel.fromWire(
        '${data['experience_level'] ?? ''}',
      ),
      workoutTypes: decodeWireList(
        data['workout_types'] as List<dynamic>? ?? const [],
        WorkoutType.fromWire,
      ),
      fitnessGoals: decodeWireList(
        data['fitness_goals'] as List<dynamic>? ?? const [],
        FitnessGoal.fromWire,
      ),
      preferredDays: decodeWireList(
        data['preferred_days'] as List<dynamic>? ?? const [],
        Weekday.fromWire,
      ),
      workoutsPerWeek: data['workouts_per_week'] as int? ?? 3,
      onboardingComplete: data['onboarding_complete'] as bool? ?? false,
      createdAt: createdAtRaw is String
          ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'name': name,
      'email': email,
      'experience_level': experienceLevel?.wire ?? '',
      'workout_types': encodeWireList(workoutTypes),
      'fitness_goals': encodeWireList(fitnessGoals),
      'preferred_days': encodeWireList(preferredDays),
      'workouts_per_week': workoutsPerWeek,
      'onboarding_complete': onboardingComplete,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    ExperienceLevel? experienceLevel,
    List<WorkoutType>? workoutTypes,
    List<FitnessGoal>? fitnessGoals,
    List<Weekday>? preferredDays,
    int? workoutsPerWeek,
    bool? onboardingComplete,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      workoutTypes: workoutTypes ?? this.workoutTypes,
      fitnessGoals: fitnessGoals ?? this.fitnessGoals,
      preferredDays: preferredDays ?? this.preferredDays,
      workoutsPerWeek: workoutsPerWeek ?? this.workoutsPerWeek,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Deep equality on the list fields is what stops every profile stream
  // emission from looking like a change and rebuilding every watcher.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          other.uid == uid &&
          other.name == name &&
          other.email == email &&
          other.experienceLevel == experienceLevel &&
          other.workoutsPerWeek == workoutsPerWeek &&
          other.onboardingComplete == onboardingComplete &&
          other.createdAt == createdAt &&
          listEquals(other.workoutTypes, workoutTypes) &&
          listEquals(other.fitnessGoals, fitnessGoals) &&
          listEquals(other.preferredDays, preferredDays);

  @override
  int get hashCode => Object.hash(
    uid,
    name,
    email,
    experienceLevel,
    workoutsPerWeek,
    onboardingComplete,
    createdAt,
    Object.hashAll(workoutTypes),
    Object.hashAll(fitnessGoals),
    Object.hashAll(preferredDays),
  );

  @override
  String toString() => 'UserModel($uid, $name, onboarded: $onboardingComplete)';
}
