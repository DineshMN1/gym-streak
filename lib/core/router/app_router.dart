import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_streak/core/router/redirect_resolver.dart';
import 'package:gym_streak/features/auth/providers/auth_provider.dart';
import 'package:gym_streak/features/auth/screens/login_screen.dart';
import 'package:gym_streak/features/auth/screens/register_screen.dart';
import 'package:gym_streak/features/auth/screens/welcome_screen.dart';
import 'package:gym_streak/features/onboarding/screens/onboarding_screen.dart';
import 'package:gym_streak/features/splash/screens/splash_screen.dart';
import 'package:gym_streak/shell/app_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Re-runs the router's redirect whenever the auth session changes.
///
/// Without this, `redirect` only fires on navigation — so a session that ends
/// without an explicit `context.go` (a refresh-token expiry, a sign-out
/// triggered elsewhere) would leave the user sitting inside the app with every
/// query failing.
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's router.
///
/// Built through a provider so `redirect` can consult the cached profile for
/// onboarding status. The policy itself lives in [resolveRedirect], which is
/// pure and unit-tested; everything here is wiring.
final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = AuthRefreshNotifier(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      // `read`, not `watch`: watching would rebuild the router and reset
      // navigation. The refreshListenable above is what re-triggers this.
      final profile = ref.read(currentUserProfileProvider).valueOrNull;

      return resolveRedirect(
        location: state.matchedLocation,
        isAuthenticated: Supabase.instance.client.auth.currentUser != null,
        onboardingComplete: profile?.onboardingComplete ?? false,
        isProfileKnown: profile != null,
      );
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
});
