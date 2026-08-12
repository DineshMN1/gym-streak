import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/router/app_router.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/features/home/widgets/streak_home_widget.dart';

class GymStreakApp extends ConsumerWidget {
  const GymStreakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched here so it lives as long as the app does. Anywhere lower and the
    // home-screen widget would stop updating whenever that screen was disposed.
    ref.watch(streakWidgetSyncProvider);

    return MaterialApp.router(
      title: 'Gym Streak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
