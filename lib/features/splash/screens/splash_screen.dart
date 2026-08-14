import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_streak/core/branding/streak_mark.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/features/auth/providers/auth_provider.dart';
import 'package:gym_streak/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Long enough for the entrance animation to read as deliberate,
  /// short enough not to tax a daily user. The animation itself
  /// completes at roughly 1.8s; this is the floor, not a wait.
  static const Duration _minimumSplash = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      // Nothing to fetch; just let the animation land.
      await Future.delayed(_minimumSplash);
      if (!mounted) return;
      context.go('/welcome');
      return;
    }

    // Start the fetch immediately and let it run *alongside* the animation.
    // Previously the app waited out a fixed 2.8s and only then began the
    // request, so time-to-content was the delay plus a full round trip on
    // every single launch.
    final profileFuture = ref
        .read(authRepositoryProvider)
        .getUserProfile(user.id);
    final results = await Future.wait([
      profileFuture,
      Future<void>.delayed(_minimumSplash),
    ]);

    if (!mounted) return;

    final profile = results.first as UserModel?;
    context.go(
      profile == null || !profile.onboardingComplete ? '/onboarding' : '/home',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The app mark, not a stock flame. Same painter the launcher
            // icons are generated from, so the splash and the home screen
            // cannot drift apart.
            const StreakMark(size: 112, includeBackground: true)
                .animate()
                .scale(
                  begin: const Offset(0.0, 0.0),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .then()
                .shimmer(
                  duration: 800.ms,
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),

            const SizedBox(height: 28),

            // App name with staggered letter animation
            Text(
                  'GYM STREAK',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    letterSpacing: 6,
                    fontWeight: FontWeight.w900,
                  ),
                )
                .animate(delay: 400.ms)
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 12),

            // Tagline
            Text(
                  'Never break the chain',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1,
                  ),
                )
                .animate(delay: 800.ms)
                .fadeIn(duration: 600.ms)
                .slideY(begin: 0.5, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 64),

            // Loading indicator
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ).animate(delay: 1400.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
