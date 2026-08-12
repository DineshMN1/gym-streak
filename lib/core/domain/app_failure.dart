import 'package:supabase_flutter/supabase_flutter.dart';

/// Something that went wrong, in terms the app can reason about.
///
/// Replaces the previous approach of stringifying an exception and searching it
/// for substrings. That was not merely ugly — the substrings the auth screens
/// looked for (`email-already-in-use`, `wrong-password`) were **Firebase** error
/// codes, which Supabase never emits, so every branch was dead and every failure
/// fell through to a generic "please try again".
///
/// Being `sealed` is the fix: a `switch` over an [AppFailure] must cover every
/// case or it will not compile, so a new failure mode cannot silently land in a
/// catch-all again.
sealed class AppFailure implements Exception {
  const AppFailure({required this.message, this.debugDetail});

  /// Safe to show a user. Never contains raw exception text, table names or
  /// anything else that leaks the shape of the backend.
  final String message;

  /// The underlying technical description, for logs and bug reports only.
  final String? debugDetail;

  /// Classifies an arbitrary caught [error].
  ///
  /// Total by construction: anything unrecognised becomes [UnknownFailure], so
  /// callers never have to handle "no match".
  static AppFailure from(Object error) {
    if (error is AppFailure) return error;

    if (error is AuthRetryableFetchException) {
      return OfflineFailure(debugDetail: error.message);
    }

    if (error is AuthException) return _fromAuth(error);

    if (error is PostgrestException) {
      // 42501 is insufficient_privilege — with RLS on, that is what a policy
      // denial looks like from the client.
      if (error.code == '42501') {
        return PermissionDenied(debugDetail: error.message);
      }
      return UnknownFailure(debugDetail: error.message);
    }

    return UnknownFailure(debugDetail: error.toString());
  }

  static AppFailure _fromAuth(AuthException error) {
    final detail = error.message;

    // Prefer the structured code; it is stable across wording changes.
    switch (error.code) {
      case 'email_exists':
      case 'user_already_exists':
        return EmailAlreadyRegistered(debugDetail: detail);
      case 'weak_password':
        return WeakPassword(debugDetail: detail);
      case 'email_not_confirmed':
        return EmailNotConfirmed(debugDetail: detail);
      case 'invalid_credentials':
        return InvalidCredentials(debugDetail: detail);
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
      case 'over_sms_send_rate_limit':
        return TooManyRequests(debugDetail: detail);
    }

    // Older responses carry no code at all, only prose.
    final text = detail.toLowerCase();
    if (text.contains('invalid login credentials')) {
      return InvalidCredentials(debugDetail: detail);
    }
    if (text.contains('already registered')) {
      return EmailAlreadyRegistered(debugDetail: detail);
    }

    return UnknownFailure(debugDetail: detail);
  }
}

final class EmailAlreadyRegistered extends AppFailure {
  const EmailAlreadyRegistered({super.debugDetail})
    : super(message: 'An account with this email already exists.');
}

final class InvalidCredentials extends AppFailure {
  const InvalidCredentials({super.debugDetail})
    : super(message: 'Incorrect email or password.');
}

final class WeakPassword extends AppFailure {
  const WeakPassword({super.debugDetail})
    : super(message: 'Please choose a stronger password.');
}

final class EmailNotConfirmed extends AppFailure {
  const EmailNotConfirmed({super.debugDetail})
    : super(message: 'Check your inbox and confirm your email first.');
}

final class TooManyRequests extends AppFailure {
  const TooManyRequests({super.debugDetail})
    : super(message: 'Too many attempts. Please wait a moment and try again.');
}

final class PermissionDenied extends AppFailure {
  const PermissionDenied({super.debugDetail})
    : super(message: "You don't have permission to do that.");
}

final class OfflineFailure extends AppFailure {
  const OfflineFailure({super.debugDetail})
    : super(message: 'No connection. Check your network and try again.');
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.debugDetail})
    : super(message: 'Something went wrong. Please try again.');
}

/// Runs [operation], converting anything it throws into an [AppFailure].
///
/// Repositories wrap their calls in this so callers only ever have to handle
/// one error type, and so a raw `PostgrestException` never reaches the UI.
Future<T> guardFailures<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } catch (error) {
    throw AppFailure.from(error);
  }
}

/// The stream equivalent of [guardFailures]: values pass through, errors are
/// converted.
Stream<T> guardFailureStream<T>(Stream<T> source) {
  return source.handleError((Object error) => throw AppFailure.from(error));
}
