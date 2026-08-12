import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/features/auth/email_validation.dart';

void main() {
  group('validateEmail accepts real addresses', () {
    // Every one of these was rejected by the previous regex,
    // ^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+ — which allowed no '+', no '_'
    // and no hyphen in the domain.
    const valid = [
      'dinesh@example.com',
      'user+gym@gmail.com',
      'first_last@example.com',
      'me@my-site.com',
      'someone@mail.example.co.uk',
      "o'brien@example.com",
      'UPPER@EXAMPLE.COM',
    ];

    for (final email in valid) {
      test('accepts $email', () => expect(validateEmail(email), isNull));
    }
  });

  group('validateEmail rejects what is clearly not an address', () {
    test('rejects null and empty', () {
      expect(validateEmail(null), isNotNull);
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('   '), isNotNull);
    });

    test('rejects a missing @', () {
      expect(validateEmail('nope'), isNotNull);
    });

    test('rejects an empty local part or domain', () {
      expect(validateEmail('@example.com'), isNotNull);
      expect(validateEmail('me@'), isNotNull);
    });

    test('rejects a domain with no dot', () {
      expect(validateEmail('me@localhost'), isNotNull);
    });

    test('rejects internal whitespace', () {
      expect(validateEmail('a b@example.com'), isNotNull);
    });

    test('rejects more than one @', () {
      expect(validateEmail('a@b@example.com'), isNotNull);
    });
  });

  group('validateEmail messages', () {
    test('explains what is wrong rather than just failing', () {
      expect(validateEmail(''), contains('email'));
      expect(validateEmail('nope'), contains('valid'));
    });
  });

  group('validatePassword', () {
    test('accepts a password of at least six characters', () {
      expect(validatePassword('sixxxx'), isNull);
    });

    test('rejects a short or missing password', () {
      expect(validatePassword(null), isNotNull);
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('five5'), isNotNull);
    });
  });
}
