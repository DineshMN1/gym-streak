import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/domain/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('guardFailures', () {
    test('returns the value when nothing goes wrong', () async {
      expect(await guardFailures(() async => 42), 42);
    });

    test('converts a Supabase error into the matching AppFailure', () async {
      expect(
        () => guardFailures<void>(
          () async => throw const AuthException('x', code: 'email_exists'),
        ),
        throwsA(isA<EmailAlreadyRegistered>()),
      );
    });

    test('converts an arbitrary error into UnknownFailure', () async {
      expect(
        () => guardFailures<void>(() async => throw StateError('boom')),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test('lets an AppFailure through unchanged', () async {
      // Repositories that already threw a typed failure must not be
      // re-wrapped into something less specific.
      expect(
        () => guardFailures<void>(() async => throw const OfflineFailure()),
        throwsA(isA<OfflineFailure>()),
      );
    });
  });

  group('guardFailureStream', () {
    test('passes values through untouched', () async {
      final values = await guardFailureStream(
        Stream.fromIterable([1, 2, 3]),
      ).toList();
      expect(values, [1, 2, 3]);
    });

    test('converts stream errors into AppFailure', () async {
      final stream = guardFailureStream<int>(
        Stream.error(const PostgrestException(message: 'no', code: '42501')),
      );
      expect(stream, emitsError(isA<PermissionDenied>()));
    });
  });
}
