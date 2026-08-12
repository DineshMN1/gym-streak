import 'package:gym_streak/core/domain/experience_level.dart';
import 'package:gym_streak/core/domain/fitness_goal.dart';
import 'package:gym_streak/core/domain/weekday.dart';
import 'package:gym_streak/core/domain/wire_enum.dart';
import 'package:gym_streak/core/domain/workout_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> saveOnboardingData({
    required String uid,
    required ExperienceLevel experienceLevel,
    required List<WorkoutType> workoutTypes,
    required List<FitnessGoal> fitnessGoals,
    required List<Weekday> preferredDays,
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
          'experience_level': experienceLevel.wire,
          'workout_types': encodeWireList(workoutTypes),
          'fitness_goals': encodeWireList(fitnessGoals),
          'preferred_days': encodeWireList(preferredDays),
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
