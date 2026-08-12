import 'package:gym_streak/core/domain/wire_enum.dart';

/// A kind of workout a user can log.
///
/// [wire] is the database contract and is pinned by a test. [label] is display
/// text and may be changed freely. Icons live in the UI layer so this file
/// stays free of Flutter imports.
enum WorkoutType implements WireEnum {
  strength('strength', 'Strength'),
  cardio('cardio', 'Cardio'),
  hiit('hiit', 'HIIT'),
  yoga('yoga', 'Yoga'),
  calisthenics('calisthenics', 'Calisthenics'),
  crossfit('crossfit', 'CrossFit'),
  swimming('swimming', 'Swimming'),
  running('running', 'Running');

  const WorkoutType(this.wire, this.label);

  @override
  final String wire;

  @override
  final String label;

  /// The type stored as [code], or null when this build does not know it.
  static WorkoutType? fromWire(String code) {
    for (final value in values) {
      if (value.wire == code) return value;
    }
    return null;
  }
}
