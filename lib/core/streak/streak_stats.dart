/// The three numbers the UI shows for a user's workout history.
///
/// Deliberately free of any Flutter or Supabase import so the streak maths can
/// be tested as plain Dart.
class StreakStats {
  const StreakStats({
    required this.current,
    required this.best,
    required this.total,
  });

  /// Length of the run of consecutive days ending today or yesterday.
  final int current;

  /// Longest run of consecutive days ever recorded.
  final int best;

  /// Number of distinct days with at least one workout.
  final int total;

  static const StreakStats empty = StreakStats(current: 0, best: 0, total: 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakStats &&
          other.current == current &&
          other.best == best &&
          other.total == total;

  @override
  int get hashCode => Object.hash(current, best, total);

  @override
  String toString() =>
      'StreakStats(current: $current, best: $best, total: $total)';
}
