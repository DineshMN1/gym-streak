import 'package:gym_streak/core/domain/wire_enum.dart';

/// What a user is training towards, collected during onboarding.
enum FitnessGoal implements WireEnum {
  buildMuscle('build_muscle', 'Build Muscle'),
  loseWeight('lose_weight', 'Lose Weight'),
  stayFit('stay_fit', 'Stay Fit'),
  increaseEndurance('increase_endurance', 'Increase Endurance'),
  flexibility('flexibility', 'Flexibility'),
  gainStrength('gain_strength', 'Gain Strength');

  const FitnessGoal(this.wire, this.label);

  @override
  final String wire;

  @override
  final String label;

  /// The goal stored as [code], or null when this build does not know it.
  static FitnessGoal? fromWire(String code) {
    for (final value in values) {
      if (value.wire == code) return value;
    }
    return null;
  }
}
