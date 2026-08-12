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
    // `.select()` is load-bearing, not decoration. A Postgres UPDATE that
    // matches zero rows SUCCEEDS — so without reading the result back, a missing
    // profile row would let onboarding report success, leave
    // `onboarding_complete` false, and drop the user back into onboarding on
    // every launch with no error ever shown.
    final rows = await _client
        .from('profiles')
        .update({
          'experience_level': experienceLevel,
          'workout_types': workoutTypes,
          'fitness_goals': fitnessGoals,
          'preferred_days': preferredDays,
          'workouts_per_week': workoutsPerWeek,
          'onboarding_complete': true,
        })
        .eq('id', uid)
        .select();

    if (rows.isEmpty) {
      throw StateError(
        'No profile row for $uid — the on_auth_user_created trigger did not run.',
      );
    }
  }
}
