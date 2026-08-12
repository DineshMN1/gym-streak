import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppFailure.from maps Supabase auth errors by code', () {
    test('email_exists means the account already exists', () {
      expect(
        AppFailure.from(const AuthException('x', code: 'email_exists')),
        isA<EmailAlreadyRegistered>(),
      );
    });

    test('user_already_exists also means the account already exists', () {
      expect(
        AppFailure.from(const AuthException('x', code: 'user_already_exists')),
        isA<EmailAlreadyRegistered>(),
      );
    });

    test('weak_password is reported as such', () {
      expect(
        AppFailure.from(const AuthException('x', code: 'weak_password')),
        isA<WeakPassword>(),
      );
    });

    test('email_not_confirmed is reported as such', () {
      expect(
        AppFailure.from(const AuthException('x', code: 'email_not_confirmed')),
        isA<EmailNotConfirmed>(),
      );
    });

    test('invalid_credentials is reported as such', () {
      expect(
        AppFailure.from(const AuthException('x', code: 'invalid_credentials')),
        isA<InvalidCredentials>(),
      );
    });

    test('rate limiting is reported as such', () {
      expect(
        AppFailure.from(
          const AuthException('x', code: 'over_request_rate_limit'),
        ),
        isA<TooManyRequests>(),
      );
    });
  });

  group('AppFailure.from falls back to the message when no code is given', () {
    test('recognises invalid login credentials', () {
      // Older Supabase responses carry no `code`, only prose.
      expect(
        AppFailure.from(const AuthException('Invalid login credentials')),
        isA<InvalidCredentials>(),
      );
    });

    test('recognises an already-registered user', () {
      expect(
        AppFailure.from(const AuthException('User already registered')),
        isA<EmailAlreadyRegistered>(),
      );
    });
  });

  group('AppFailure.from maps transport and database errors', () {
    test('a retryable fetch failure means offline', () {
      expect(
        AppFailure.from(AuthRetryableFetchException(statusCode: '0')),
        isA<OfflineFailure>(),
      );
    });

    test('postgres 42501 is an RLS denial', () {
      expect(
        AppFailure.from(
          const PostgrestException(message: 'denied', code: '42501'),
        ),
        isA<PermissionDenied>(),
      );
    });

    test('an unrecognised postgres error is unknown, not misreported', () {
      expect(
        AppFailure.from(
          const PostgrestException(message: 'boom', code: '99999'),
        ),
        isA<UnknownFailure>(),
      );
    });
  });

  group('AppFailure.from is total', () {
    test('an unknown auth code does not throw', () {
      expect(
        AppFailure.from(const AuthException('x', code: 'brand_new_code')),
        isA<UnknownFailure>(),
      );
    });

    test('an arbitrary object becomes UnknownFailure', () {
      expect(AppFailure.from(StateError('nope')), isA<UnknownFailure>());
      expect(AppFailure.from('a bare string'), isA<UnknownFailure>());
    });

    test('an AppFailure passes through unchanged', () {
      const original = OfflineFailure();
      expect(identical(AppFailure.from(original), original), isTrue);
    });
  });

  group('AppFailure messages', () {
    test('every failure carries a non-empty user-facing message', () {
      final all = <AppFailure>[
        const EmailAlreadyRegistered(),
        const InvalidCredentials(),
        const WeakPassword(),
        const EmailNotConfirmed(),
        const TooManyRequests(),
        const PermissionDenied(),
        const OfflineFailure(),
        const UnknownFailure(),
      ];
      for (final f in all) {
        expect(
          f.message,
          isNotEmpty,
          reason: '${f.runtimeType} has no message',
        );
      }
    });

    test('the raw technical text is kept out of the user-facing message', () {
      final failure = AppFailure.from(
        const PostgrestException(
          message: 'relation "public.workouts" does not exist',
          code: '42P01',
        ),
      );
      expect(failure.message, isNot(contains('relation')));
      expect(failure.debugDetail, contains('relation'));
    });

    test('a switch over AppFailure is exhaustive', () {
      // This only compiles while the switch covers every subtype — the
      // compile-time guarantee that replaces substring matching.
      String describe(AppFailure f) => switch (f) {
        EmailAlreadyRegistered() => 'exists',
        InvalidCredentials() => 'bad-credentials',
        WeakPassword() => 'weak',
        EmailNotConfirmed() => 'unconfirmed',
        TooManyRequests() => 'rate-limited',
        PermissionDenied() => 'denied',
        OfflineFailure() => 'offline',
        UnknownFailure() => 'unknown',
      };
      expect(describe(const OfflineFailure()), 'offline');
    });
  });
}
