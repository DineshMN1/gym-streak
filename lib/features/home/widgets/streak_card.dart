import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/features/home/providers/workout_provider.dart';

class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakDataProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.primary,
                size: 48,
              ),
              const SizedBox(width: 8),
              Text(
                '${streak.current}',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            streak.current == 1 ? 'day streak' : 'day streak',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                label: 'Best Streak',
                value: '${streak.best}',
                icon: Icons.emoji_events_rounded,
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              _StatItem(
                label: 'Total',
                value: '${streak.total}',
                icon: Icons.fitness_center_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
