/// A domain enum whose **stored** representation is separate from its
/// **displayed** one.
///
/// The app previously stored display strings directly — `'Build Muscle'` was
/// both the chip text and the value in Postgres. That couples two things with
/// opposite requirements: a label wants to be reworded, capitalised differently
/// or translated, while a stored code must never change or every existing row
/// is orphaned.
///
/// Implementors keep [wire] frozen and are free to change [label] at will.
abstract interface class WireEnum {
  /// The stable code persisted to the database. Treat as frozen.
  String get wire;

  /// Human-readable text for the UI. Safe to reword or localise.
  String get label;
}

/// Decodes a list of stored codes, silently dropping anything unrecognised.
///
/// Rows are written by clients that may be newer than this one, so an unknown
/// code is an expected condition rather than corruption — dropping it keeps an
/// old build usable instead of crashing it.
List<T> decodeWireList<T extends WireEnum>(
  List<dynamic> raw,
  T? Function(String) fromWire,
) {
  final out = <T>[];
  for (final entry in raw) {
    if (entry is! String) continue;
    final decoded = fromWire(entry);
    if (decoded != null) out.add(decoded);
  }
  return out;
}

/// The stored codes for [values], ready to hand to the database.
List<String> encodeWireList(Iterable<WireEnum> values) =>
    values.map((v) => v.wire).toList();
