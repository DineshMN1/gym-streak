import 'package:flutter/material.dart';
import 'package:gym_streak/core/domain/workout_type.dart';

class AppConstants {
  AppConstants._();

  /// The icon shown for each workout type.
  ///
  /// Kept here rather than on [WorkoutType] itself so the domain layer stays
  /// free of Flutter imports and testable as plain Dart. The option lists that
  /// used to live in this file are gone — `WorkoutType.values`,
  /// `FitnessGoal.values`, `ExperienceLevel.values` and `Weekday.values` are
  /// now the single source of truth, and each carries its own display label.
  static const Map<WorkoutType, IconData> workoutIcons = {
    WorkoutType.strength: Icons.fitness_center_rounded,
    WorkoutType.cardio: Icons.monitor_heart_rounded,
    WorkoutType.hiit: Icons.bolt_rounded,
    WorkoutType.yoga: Icons.self_improvement_rounded,
    WorkoutType.calisthenics: Icons.sports_gymnastics_rounded,
    WorkoutType.crossfit: Icons.local_fire_department_rounded,
    WorkoutType.swimming: Icons.pool_rounded,
    WorkoutType.running: Icons.directions_run_rounded,
  };

  /// The icon for [type], falling back to a generic one.
  static IconData iconFor(WorkoutType type) =>
      workoutIcons[type] ?? Icons.sports_rounded;
}
