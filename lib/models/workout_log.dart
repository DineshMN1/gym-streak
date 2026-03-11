class WorkoutLog {
  final String date; // yyyy-MM-dd format
  final String workoutType;
  final DateTime completedAt;

  const WorkoutLog({
    required this.date,
    required this.workoutType,
    required this.completedAt,
  });

  factory WorkoutLog.fromMap(Map<String, dynamic> data) {
    return WorkoutLog(
      date: data['date'] ?? '',
      workoutType: data['workout_type'] ?? '',
      completedAt:
          data['completed_at'] != null
              ? DateTime.parse(data['completed_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap(String uid) {
    return {
      'user_id': uid,
      'date': date,
      'workout_type': workoutType,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}
