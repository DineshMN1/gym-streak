import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/features/reminders/reminder_provider.dart';
import 'package:gym_streak/features/auth/providers/auth_provider.dart';
import 'package:gym_streak/features/home/providers/workout_provider.dart';
import 'package:gym_streak/models/user_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(currentUserProfileProvider);
    final streak = ref.watch(streakDataProvider);

    return Scaffold(
      body: SafeArea(
        child: userProfile.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('User not found'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                children: [
                  // Header
                  const SizedBox(height: 8),
                  _buildAvatar(context, user),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  // Stats grid
                  _buildStatsGrid(context, streak, user),
                  const SizedBox(height: 24),

                  _buildReminderToggle(context, ref, user),
                  const SizedBox(height: 24),

                  // Preferences
                  _buildSection(
                    context,
                    title: 'Experience Level',
                    icon: Icons.trending_up_rounded,
                    child: _buildChip(user.experienceLevel?.label ?? 'Not set'),
                  ),
                  const SizedBox(height: 16),

                  _buildSection(
                    context,
                    title: 'Workout Types',
                    icon: Icons.fitness_center_rounded,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.workoutTypes
                          .map((t) => _buildChip(t.label))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSection(
                    context,
                    title: 'Fitness Goals',
                    icon: Icons.flag_rounded,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.fitnessGoals
                          .map((g) => _buildChip(g.label))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSection(
                    context,
                    title: 'Workout Schedule',
                    icon: Icons.calendar_month_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: user.preferredDays
                              .map((d) => _buildChip(d.label))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${user.workoutsPerWeek} workouts per week',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context, ref),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                      ),
                      label: const Text(
                        'Logout',
                        style: TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Gym Streak v1.0.0',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: Text(
              'Error loading profile',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, UserModel user) {
    final initials = user.name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.background,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    StreakStats streak,
    UserModel user,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Current Streak',
            value: '${streak.current}',
            icon: Icons.local_fire_department_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Best Streak',
            value: '${streak.best}',
            icon: Icons.emoji_events_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Total',
            value: '${streak.total}',
            icon: Icons.fitness_center_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
              Icon(icon, size: 18, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authRepositoryProvider).logout();
              if (context.mounted) context.go('/welcome');
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Reminders follow the training plan, so the copy says which days.
  Widget _buildReminderToggle(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) {
    final enabled = ref.watch(remindersEnabledProvider).valueOrNull ?? false;
    final days = user.preferredDays.isEmpty
        ? 'every day'
        : user.preferredDays.map((d) => d.label).join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: enabled,
        activeThumbColor: AppColors.primary,
        title: const Text('Workout reminders'),
        subtitle: Text(
          enabled ? 'At 6pm on $days' : 'Off',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        secondary: const Icon(
          Icons.notifications_active_rounded,
          color: AppColors.primary,
        ),
        onChanged: (value) async {
          await ref
              .read(reminderServiceProvider)
              .setEnabled(
                enabled: value,
                scheduledDays: user.preferredDays.toSet(),
              );
          ref.invalidate(remindersEnabledProvider);
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
