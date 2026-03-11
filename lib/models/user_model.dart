class UserModel {
  final String uid;
  final String name;
  final String email;
  final String experienceLevel;
  final List<String> workoutTypes;
  final List<String> fitnessGoals;
  final List<String> preferredDays;
  final int workoutsPerWeek;
  final bool onboardingComplete;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.experienceLevel = '',
    this.workoutTypes = const [],
    this.fitnessGoals = const [],
    this.preferredDays = const [],
    this.workoutsPerWeek = 3,
    this.onboardingComplete = false,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['id'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      experienceLevel: data['experience_level'] ?? '',
      workoutTypes: List<String>.from(data['workout_types'] ?? []),
      fitnessGoals: List<String>.from(data['fitness_goals'] ?? []),
      preferredDays: List<String>.from(data['preferred_days'] ?? []),
      workoutsPerWeek: data['workouts_per_week'] ?? 3,
      onboardingComplete: data['onboarding_complete'] ?? false,
      createdAt:
          data['created_at'] != null
              ? DateTime.parse(data['created_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'name': name,
      'email': email,
      'experience_level': experienceLevel,
      'workout_types': workoutTypes,
      'fitness_goals': fitnessGoals,
      'preferred_days': preferredDays,
      'workouts_per_week': workoutsPerWeek,
      'onboarding_complete': onboardingComplete,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? experienceLevel,
    List<String>? workoutTypes,
    List<String>? fitnessGoals,
    List<String>? preferredDays,
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
}
