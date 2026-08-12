/// Routes that a signed-out visitor is allowed to sit on.
const Set<String> authRoutes = {'/welcome', '/login', '/register'};

/// The route to redirect to, or null to allow [location] as requested.
///
/// Pure so the whole routing policy can be tested without a navigator, a
/// widget tree, or a live Supabase session — the wiring in `app_router.dart`
/// only has to supply the three facts below.
///
/// [isProfileKnown] distinguishes "this user has not onboarded" from "the
/// profile has not loaded yet". Collapsing the two would throw an established
/// user into onboarding for a frame on every cold start.
String? resolveRedirect({
  required String location,
  required bool isAuthenticated,
  required bool onboardingComplete,
  required bool isProfileKnown,
}) {
  // Splash owns its own timing and navigates itself.
  if (location == '/splash') return null;

  final isOnAuthRoute = authRoutes.contains(location);

  if (!isAuthenticated) {
    return isOnAuthRoute ? null : '/welcome';
  }

  // Signed in from here on. Wait for the profile before judging onboarding.
  if (isProfileKnown && !onboardingComplete) {
    return location == '/onboarding' ? null : '/onboarding';
  }

  if (isOnAuthRoute) return '/home';

  // Onboarding is done (or not yet known); don't strand the user on it.
  if (location == '/onboarding' && isProfileKnown) return '/home';

  return null;
}
