import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/constants/app_constants.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/features/home/providers/workout_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TodayCheckin extends ConsumerWidget {
  const TodayCheckin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayWorkout = ref.watch(todayWorkoutProvider);

    return todayWorkout.when(
      data: (workout) {
        final isCheckedIn = workout != null;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isCheckedIn
                      ? AppColors.success.withValues(alpha: 0.5)
                      : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCheckedIn
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color:
                        isCheckedIn
                            ? AppColors.success
                            : AppColors.textTertiary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isCheckedIn ? 'Workout Complete!' : "Today's Workout",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color:
                          isCheckedIn
                              ? AppColors.success
                              : AppColors.textPrimary,
                    ),
                  ),
                  if (isCheckedIn) ...[
                    const Spacer(),
                    Text(
                      workout.workoutType,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              if (!isCheckedIn) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _showWorkoutTypeSheet(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Log Workout'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading:
          () => Container(
            width: double.infinity,
            height: 80,
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

  void _showWorkoutTypeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'What did you do today?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      AppConstants.workoutTypes.map((type) {
                        final icon =
                            AppConstants.workoutIcons[type] ??
                            Icons.sports_rounded;
                        return GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            final uid =
                                Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) return;
                            await ref
                                .read(workoutRepositoryProvider)
                                .logWorkout(uid: uid, workoutType: type);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  type,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
    );
  }
}
