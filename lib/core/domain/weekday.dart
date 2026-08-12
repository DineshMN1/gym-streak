import 'package:gym_streak/core/domain/wire_enum.dart';

/// A day of the week, used for the preferred-training-days picker.
///
/// [label] is the short form the picker renders; [wire] is spelled out so the
/// stored value is unambiguous when read straight out of the database.
enum Weekday implements WireEnum {
  monday('monday', 'Mon'),
  tuesday('tuesday', 'Tue'),
  wednesday('wednesday', 'Wed'),
  thursday('thursday', 'Thu'),
  friday('friday', 'Fri'),
  saturday('saturday', 'Sat'),
  sunday('sunday', 'Sun');

  const Weekday(this.wire, this.label);

  @override
  final String wire;

  @override
  final String label;

  /// The day stored as [code], or null when this build does not know it.
  static Weekday? fromWire(String code) {
    for (final value in values) {
      if (value.wire == code) return value;
    }
    return null;
  }
}
