import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/core/router/app_router.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/features/home/providers/workout_provider.dart';
import 'package:gym_streak/features/home/widgets/streak_home_widget.dart';
import 'package:gym_streak/features/home/widgets/today_checkin.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GymStreakApp extends ConsumerStatefulWidget {
  const GymStreakApp({super.key});

  @override
  ConsumerState<GymStreakApp> createState() => _GymStreakAppState();
}

class _GymStreakAppState extends ConsumerState<GymStreakApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flushPendingWorkouts();
    _listenForWidgetTaps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the foreground is the most reliable moment to discover
    // the network has returned — the user has usually walked out of the gym.
    if (state == AppLifecycleState.resumed) _flushPendingWorkouts();
  }

  /// Opens the workout picker when the home-screen widget is tapped, whether
  /// the app was already running or was launched by the tap.
  Future<void> _listenForWidgetTaps() async {
    HomeWidget.widgetClicked.listen((_) => _openWorkoutPicker());
    final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (launchUri != null) _openWorkoutPicker();
  }

  void _openWorkoutPicker() {
    // Deferred a frame: on a cold launch the navigator does not exist yet when
    // the launch intent arrives.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      showWorkoutTypeSheet(context, ref);
    });
  }

  Future<void> _flushPendingWorkouts() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await ref.read(workoutRepositoryProvider).flushPending(uid);
    if (mounted) ref.invalidate(pendingWorkoutsProvider);
  }

  @override
  Widget build(BuildContext context) {
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
