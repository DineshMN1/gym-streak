import 'package:gym_streak/core/domain/wire_enum.dart';

/// How much training experience a user reports during onboarding.
enum ExperienceLevel implements WireEnum {
  beginner('beginner', 'Beginner'),
  intermediate('intermediate', 'Intermediate'),
  advanced('advanced', 'Advanced');

  const ExperienceLevel(this.wire, this.label);

  @override
  final String wire;

  @override
  final String label;

  /// The level stored as [code], or null when this build does not know it.
  static ExperienceLevel? fromWire(String code) {
    for (final value in values) {
      if (value.wire == code) return value;
    }
    return null;
  }
}
