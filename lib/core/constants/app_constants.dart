import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const List<String> experienceLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  static const List<String> workoutTypes = [
    'Strength',
    'Cardio',
    'HIIT',
    'Yoga',
    'Calisthenics',
    'CrossFit',
    'Swimming',
    'Running',
  ];

  static const List<String> fitnessGoals = [
    'Build Muscle',
    'Lose Weight',
    'Stay Fit',
    'Increase Endurance',
    'Flexibility',
    'Gain Strength',
  ];

  static const List<String> weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const Map<String, IconData> workoutIcons = {
    'Strength': Icons.fitness_center_rounded,
    'Cardio': Icons.monitor_heart_rounded,
    'HIIT': Icons.bolt_rounded,
    'Yoga': Icons.self_improvement_rounded,
    'Calisthenics': Icons.sports_gymnastics_rounded,
    'CrossFit': Icons.local_fire_department_rounded,
    'Swimming': Icons.pool_rounded,
    'Running': Icons.directions_run_rounded,
  };
}
