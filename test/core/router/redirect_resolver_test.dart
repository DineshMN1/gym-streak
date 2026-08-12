import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/router/redirect_resolver.dart';

void main() {
  String? go(
    String location, {
    bool authed = true,
    bool onboarded = true,
    bool profileKnown = true,
  }) => resolveRedirect(
    location: location,
    isAuthenticated: authed,
    onboardingComplete: onboarded,
    isProfileKnown: profileKnown,
  );

  group('signed out', () {
    test('is sent to welcome from a protected route', () {
      expect(go('/home', authed: false), '/welcome');
      expect(go('/onboarding', authed: false), '/welcome');
    });

    test('may stay on any auth route', () {
      expect(go('/welcome', authed: false), isNull);
      expect(go('/login', authed: false), isNull);
      expect(go('/register', authed: false), isNull);
    });

    test('may ask for a password reset', () {
      // Someone who cannot sign in is by definition signed out; bouncing them
      // to /welcome would make the feature unreachable by the only people who
      // need it.
      expect(go('/forgot-password', authed: false), isNull);
    });
  });

  group('password recovery', () {
    test('the reset screen is reachable while signed out', () {
      // Following the emailed link puts the app in a recovery session that may
      // not look authenticated yet, so this must not redirect either way.
      expect(go('/reset-password', authed: false), isNull);
    });

    test('the reset screen is reachable while signed in', () {
      // Supabase signs the user in as part of the recovery flow; they still
      // need to reach the screen that sets the new password.
      expect(go('/reset-password'), isNull);
      expect(go('/reset-password', onboarded: false), isNull);
    });
  });

  group('signed in but onboarding incomplete', () {
    test('is sent to onboarding from anywhere else', () {
      // The previous router had no idea onboarding existed; only the splash
      // screen checked. Any other entry point — a deep link, a hot restart,
      // the post-register redirect — skipped it permanently.
      expect(go('/home', onboarded: false), '/onboarding');
      expect(go('/login', onboarded: false), '/onboarding');
      expect(go('/welcome', onboarded: false), '/onboarding');
    });

    test('may stay on onboarding', () {
      expect(go('/onboarding', onboarded: false), isNull);
    });
  });

  group('signed in and onboarded', () {
    test('is sent home from an auth route', () {
      expect(go('/welcome'), '/home');
      expect(go('/login'), '/home');
      expect(go('/register'), '/home');
    });

    test('is sent home from onboarding, which is already done', () {
      expect(go('/onboarding'), '/home');
    });

    test('may stay on home', () {
      expect(go('/home'), isNull);
    });
  });

  group('splash', () {
    test('is never redirected — it owns its own timing', () {
      expect(go('/splash'), isNull);
      expect(go('/splash', authed: false), isNull);
      expect(go('/splash', onboarded: false), isNull);
    });
  });

  group('profile not loaded yet', () {
    test('does not bounce a signed-in user out of the app', () {
      // Treating "unknown" as "not onboarded" would throw an existing user
      // into onboarding for a frame every cold start.
      expect(go('/home', onboarded: false, profileKnown: false), isNull);
    });

    test('still keeps a signed-out user out', () {
      expect(go('/home', authed: false, profileKnown: false), '/welcome');
    });
  });
}
