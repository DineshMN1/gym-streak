import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> saveOnboardingData({
    required String uid,
    required String experienceLevel,
    required List<String> workoutTypes,
    required List<String> fitnessGoals,
    required List<String> preferredDays,
    required int workoutsPerWeek,
  }) async {
    await _client.from('profiles').update({
      'experience_level': experienceLevel,
      'workout_types': workoutTypes,
      'fitness_goals': fitnessGoals,
      'preferred_days': preferredDays,
      'workouts_per_week': workoutsPerWeek,
      'onboarding_complete': true,
    }).eq('id', uid);
  }
}
