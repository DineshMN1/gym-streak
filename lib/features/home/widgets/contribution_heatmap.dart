import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/core/domain/calendar_date.dart';
import 'package:gym_streak/features/auth/providers/auth_provider.dart';
import 'package:gym_streak/features/home/heatmap_intensity.dart';
import 'package:gym_streak/features/home/providers/workout_provider.dart';
import 'package:intl/intl.dart';

class ContributionHeatmap extends ConsumerWidget {
  const ContributionHeatmap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(visibleWorkoutLogsProvider);

    return logsAsync.when(
      data: (logs) {
        final workoutDays = logs.map((log) => log.date).toSet();
        final profile = ref.watch(currentUserProfileProvider).valueOrNull;
        return _HeatmapGrid(
          workoutDates: workoutDays.map((d) => d.toIso()).toSet(),
          weeklyCounts: countWorkoutsPerWeek(workoutDays),
          weeklyTarget: profile?.workoutsPerWeek ?? 0,
        );
      },
      loading: () => Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final Set<String> workoutDates;
  final Map<CalendarDate, int> weeklyCounts;
  final int weeklyTarget;

  const _HeatmapGrid({
    required this.workoutDates,
    required this.weeklyCounts,
    required this.weeklyTarget,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate start date: go back ~52 weeks from today, start on Monday
    final weeksBack = 52;
    var startDate = today.subtract(Duration(days: weeksBack * 7));
    // Align to Monday
    while (startDate.weekday != DateTime.monday) {
      startDate = startDate.subtract(const Duration(days: 1));
    }

    // Build weeks
    final weeks = <List<DateTime?>>[];
    var current = startDate;
    while (current.isBefore(today) || current.isAtSameMomentAs(today)) {
      final week = <DateTime?>[];
      for (int d = 0; d < 7; d++) {
        if (current.isAfter(today)) {
          week.add(null);
        } else {
          week.add(current);
        }
        current = current.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    // Month labels
    final monthLabels = <({int weekIndex, String label})>[];
    for (int i = 0; i < weeks.length; i++) {
      final firstValidDay = weeks[i].firstWhere(
        (d) => d != null,
        orElse: () => null,
      );
      if (firstValidDay != null && firstValidDay.day <= 7) {
        monthLabels.add((
          weekIndex: i,
          label: DateFormat('MMM').format(firstValidDay),
        ));
      }
    }

    const cellSize = 12.0;
    const cellGap = 3.0;
    const dayLabelWidth = 28.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.grid_view_rounded,
                color: AppColors.textTertiary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text('Activity', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '${workoutDates.length} workouts this year',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 7 * (cellSize + cellGap) + 20, // grid + month labels
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // Show most recent on the right
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month labels row
                  SizedBox(
                    height: 16,
                    child: Row(
                      children: [
                        SizedBox(width: dayLabelWidth),
                        ...List.generate(weeks.length, (weekIdx) {
                          final label = monthLabels
                              .where((m) => m.weekIndex == weekIdx)
                              .firstOrNull;
                          return SizedBox(
                            width: cellSize + cellGap,
                            child: label != null
                                ? Text(
                                    label.label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary,
                                    ),
                                  )
                                : null,
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Grid
                  ...List.generate(7, (dayIndex) {
                    return Row(
                      children: [
                        // Day label
                        SizedBox(
                          width: dayLabelWidth,
                          height: cellSize + cellGap,
                          child:
                              (dayIndex == 0 || dayIndex == 2 || dayIndex == 4)
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _dayLabel(dayIndex),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        // Cells for each week
                        ...List.generate(weeks.length, (weekIdx) {
                          final date = weeks[weekIdx][dayIndex];
                          final day = date == null
                              ? null
                              : CalendarDate.fromDateTime(date);
                          final trained =
                              day != null && workoutDates.contains(day.toIso());
                          return _HeatmapCell(
                            date: date,
                            level: day == null
                                ? 0
                                : heatmapLevelFor(
                                    trained: trained,
                                    workoutsThatWeek:
                                        weeklyCounts[weekStartOf(day)] ?? 0,
                                    weeklyTarget: weeklyTarget,
                                  ),
                            cellSize: cellSize,
                            cellGap: cellGap,
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
              ),
              const SizedBox(width: 4),
              _LegendCell(color: AppColors.heatmapEmpty),
              _LegendCell(color: AppColors.heatmapLevel1),
              _LegendCell(color: AppColors.heatmapLevel2),
              _LegendCell(color: AppColors.heatmapLevel3),
              _LegendCell(color: AppColors.heatmapLevel4),
              const SizedBox(width: 4),
              Text(
                'More',
                style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dayLabel(int index) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[index];
  }
}

/// Colour per intensity level; index 0 is an untrained day.
const List<Color> _levelColors = [
  AppColors.heatmapEmpty,
  AppColors.heatmapLevel1,
  AppColors.heatmapLevel2,
  AppColors.heatmapLevel3,
  AppColors.heatmapLevel4,
];

class _HeatmapCell extends StatelessWidget {
  final DateTime? date;
  final int level;
  final double cellSize;
  final double cellGap;

  const _HeatmapCell({
    required this.date,
    required this.level,
    required this.cellSize,
    required this.cellGap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(cellGap / 2),
      child: Tooltip(
        // Tooltip doubles as the semantics label, so this is what a screen
        // reader announces for the cell.
        message: date != null
            ? '${DateFormat('MMM d, yyyy').format(date!)}'
                  '${level > 0 ? ' - Worked out!' : ''}'
            : '',
        child: Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: date == null ? Colors.transparent : _levelColors[level],
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}

class _LegendCell extends StatelessWidget {
  final Color color;

  const _LegendCell({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
