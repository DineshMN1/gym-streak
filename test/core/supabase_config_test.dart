import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/supabase_config.dart';

void main() {
  group('SupabaseConfig.validate', () {
    const goodUrl = 'https://abcdefghijkl.supabase.co';
    const goodKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake.key';

    test('accepts a well-formed https project URL and key', () {
      expect(
        SupabaseConfig.validate(url: goodUrl, anonKey: goodKey),
        ConfigStatus.ok,
      );
    });

    test('reports a missing URL', () {
      expect(
        SupabaseConfig.validate(url: '', anonKey: goodKey),
        ConfigStatus.missingUrl,
      );
    });

    test('treats a whitespace-only URL as missing', () {
      expect(
        SupabaseConfig.validate(url: '   ', anonKey: goodKey),
        ConfigStatus.missingUrl,
      );
    });

    test('reports a missing anon key', () {
      expect(
        SupabaseConfig.validate(url: goodUrl, anonKey: ''),
        ConfigStatus.missingAnonKey,
      );
    });

    test('treats a whitespace-only anon key as missing', () {
      expect(
        SupabaseConfig.validate(url: goodUrl, anonKey: '  '),
        ConfigStatus.missingAnonKey,
      );
    });

    test('rejects the historical hardcoded placeholder', () {
      expect(
        SupabaseConfig.validate(
          url: 'your Supabase URL',
          anonKey: 'your Supabase anon key',
        ),
        ConfigStatus.malformedUrl,
      );
    });

    test('rejects a scheme-less host', () {
      expect(
        SupabaseConfig.validate(url: 'abcd.supabase.co', anonKey: goodKey),
        ConfigStatus.malformedUrl,
      );
    });

    test('rejects plain http', () {
      expect(
        SupabaseConfig.validate(
          url: 'http://abcd.supabase.co',
          anonKey: goodKey,
        ),
        ConfigStatus.malformedUrl,
      );
    });

    test('rejects an https URL with no host', () {
      expect(
        SupabaseConfig.validate(url: 'https://', anonKey: goodKey),
        ConfigStatus.malformedUrl,
      );
    });

    test('tolerates surrounding whitespace on otherwise valid values', () {
      expect(
        SupabaseConfig.validate(url: '  $goodUrl  ', anonKey: '  $goodKey  '),
        ConfigStatus.ok,
      );
    });
  });

  group('ConfigStatus.message', () {
    test('every status has a non-empty message', () {
      for (final status in ConfigStatus.values) {
        expect(
          status.message,
          isNotEmpty,
          reason: 'missing message for $status',
        );
      }
    });
  });

  group('SupabaseConfig defaults', () {
    test('an unconfigured build is not configured', () {
      // `flutter test` runs with no --dart-define values, so the compile-time
      // constants are empty and the app must refuse to boot.
      expect(SupabaseConfig.isConfigured, isFalse);
      expect(SupabaseConfig.status, ConfigStatus.missingUrl);
    });

    test('exposes the command that fixes an unconfigured build', () {
      expect(SupabaseConfig.runCommand, contains('--dart-define-from-file'));
    });
  });
}
