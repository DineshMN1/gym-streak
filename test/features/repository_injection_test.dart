import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/features/auth/data/auth_repository.dart';
import 'package:gym_streak/features/home/data/workout_repository.dart';
import 'package:gym_streak/features/onboarding/data/onboarding_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every repository used to read `Supabase.instance.client` in a field
/// initialiser, which throws unless Supabase has been initialised — so none of
/// the data layer could be constructed in a test at all.
///
/// These tests do no I/O. They exist to prove the seam: a repository can be
/// built against a client the caller supplies, with no global in sight. If
/// someone reintroduces `Supabase.instance` in a field initialiser, they fail.
void main() {
  late SupabaseClient client;

  setUp(() {
    // Constructing a client performs no network I/O; requests are lazy.
    client = SupabaseClient('https://example.supabase.co', 'test-anon-key');
  });

  tearDown(() async {
    await client.dispose();
  });

  test('AuthRepository builds from an injected client', () {
    expect(AuthRepository(client), isA<AuthRepository>());
  });

  test('WorkoutRepository builds from an injected client', () {
    expect(WorkoutRepository(client), isA<WorkoutRepository>());
  });

  test('OnboardingRepository builds from an injected client', () {
    expect(OnboardingRepository(client), isA<OnboardingRepository>());
  });

  test('no repository touches Supabase.instance during construction', () {
    // Supabase.instance has never been initialised in this test process.
    // Reading it throws, so constructing all three without incident is the
    // assertion.
    expect(() {
      AuthRepository(client);
      WorkoutRepository(client);
      OnboardingRepository(client);
    }, returnsNormally);
  });
}
