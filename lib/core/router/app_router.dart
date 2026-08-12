import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_streak/features/auth/screens/login_screen.dart';
import 'package:gym_streak/features/auth/screens/register_screen.dart';
import 'package:gym_streak/features/auth/screens/welcome_screen.dart';
import 'package:gym_streak/features/onboarding/screens/onboarding_screen.dart';
import 'package:gym_streak/features/splash/screens/splash_screen.dart';
import 'package:gym_streak/shell/app_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      // Let splash handle its own navigation
      if (state.matchedLocation == '/splash') return null;

      final user = Supabase.instance.client.auth.currentUser;
      final isAuthenticated = user != null;
      final isAuthRoute =
          state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) {
        return '/welcome';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const AppShell()),
    ],
  );
}
