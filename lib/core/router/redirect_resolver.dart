/// Routes that a signed-out visitor is allowed to sit on.
///
/// `/forgot-password` belongs here because someone who cannot sign in is by
/// definition signed out — gating it behind a session would make it reachable
/// only by the people who do not need it.
const Set<String> authRoutes = {
  '/welcome',
  '/login',
  '/register',
  '/forgot-password',
};

/// Where a recovery link lands. Exempt from every redirect: Supabase creates a
/// recovery session when the emailed link is followed, so the user may look
/// signed in, signed out, or mid-transition — and must reach this screen in
/// all three cases.
const String resetPasswordRoute = '/reset-password';

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

  // Password recovery outranks every other rule.
  if (location == resetPasswordRoute) return null;

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
