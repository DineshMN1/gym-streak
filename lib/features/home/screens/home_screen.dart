import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/features/auth/providers/auth_provider.dart';
import 'package:gym_streak/features/home/widgets/contribution_heatmap.dart';
import 'package:gym_streak/features/home/widgets/streak_card.dart';
import 'package:gym_streak/features/home/widgets/today_checkin.dart';
import 'package:gym_streak/features/home/widgets/weekly_summary.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(currentUserProfileProvider);

    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(currentUserProfileProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        userProfile.when(
                          data: (user) => Text(
                            '$greeting, ${user?.name.split(' ').first ?? 'Champ'}!',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          loading: () => Text(
                            '$greeting!',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          error: (_, _) => Text(
                            '$greeting!',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, MMM d').format(now),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Streak card
                const StreakCard(),
                const SizedBox(height: 20),

                // Today's check-in
                const TodayCheckin(),
                const SizedBox(height: 20),

                // Weekly summary
                const WeeklySummary(),
                const SizedBox(height: 20),

                // Contribution heatmap
                const ContributionHeatmap(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
