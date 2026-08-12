import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    // Wait for animations to play
    await Future.delayed(const Duration(milliseconds: 2800));

    if (!mounted) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      context.go('/welcome');
      return;
    }

    // Check onboarding status
    final profile = await ref
        .read(authRepositoryProvider)
        .getUserProfile(user.id);

    if (!mounted) return;

    if (profile == null || !profile.onboardingComplete) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated fire icon
            Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    size: 60,
                    color: AppColors.primary,
                  ),
                )
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
