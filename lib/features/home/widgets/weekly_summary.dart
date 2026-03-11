import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/features/home/providers/workout_provider.dart';
import 'package:intl/intl.dart';

class WeeklySummary extends ConsumerWidget {
  const WeeklySummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(workoutLogsProvider);

    return logsAsync.when(
      data: (logs) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        // Find Monday of current week
        final monday = today.subtract(Duration(days: today.weekday - 1));

        final workoutDates = <String>{};
        for (final log in logs) {
          workoutDates.add(log.date);
        }

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
                    Icons.calendar_today_rounded,
                    color: AppColors.textTertiary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'This Week',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final date = monday.add(Duration(days: index));
                  final dateStr = DateFormat('yyyy-MM-dd').format(date);
                  final isToday = date.isAtSameMomentAs(today);
                  final hasWorkout = workoutDates.contains(dateStr);
                  final isFuture = date.isAfter(today);

                  return Column(
                    children: [
                      Text(
                        DateFormat('E').format(date).substring(0, 2),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isToday
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                          fontWeight:
                              isToday ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              hasWorkout
                                  ? AppColors.primary
                                  : isToday
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border:
                              isToday && !hasWorkout
                                  ? Border.all(
                                    color: AppColors.primary,
                                    width: 2,
                                  )
                                  : null,
                        ),
                        child: Center(
                          child:
                              hasWorkout
                                  ? const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: AppColors.background,
                                  )
                                  : Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          isFuture
                                              ? AppColors.textTertiary
                                              : isToday
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
