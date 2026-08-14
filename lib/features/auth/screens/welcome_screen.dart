import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_streak/core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo area
              // Bare icon: no tinted plate, no outline. The mark carries
              // itself against the dark ground.
              Icon(
                Icons.local_fire_department_rounded,
                size: 88,
                color: AppColors.primary.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 32),
              Text(
                'GYM STREAK',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Build consistency.\nTrack every workout.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 3),
              // CTA buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('I already have an account'),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
