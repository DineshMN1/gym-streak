/// Supabase credentials, supplied at build time.
///
/// Nothing is hardcoded. Values arrive through `--dart-define-from-file=env.json`
/// (see `env.example.json`) or individual `--dart-define` flags, so a build made
/// without them produces an app that refuses to boot rather than one that points
/// at a placeholder URL and fails later with an opaque network error.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The command a developer should run to fix an unconfigured build.
  static const String runCommand =
      'flutter run --dart-define-from-file=env.json';

  static ConfigStatus get status => validate(url: url, anonKey: anonKey);

  static bool get isConfigured => status == ConfigStatus.ok;

  /// Pure validation, parameterised so it can be exercised in tests.
  ///
  /// [String.fromEnvironment] is fixed at compile time, so the constants above
  /// cannot be varied per test case — the rules live here instead.
  static ConfigStatus validate({required String url, required String anonKey}) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return ConfigStatus.missingUrl;
    if (anonKey.trim().isEmpty) return ConfigStatus.missingAnonKey;

    // `Uri.tryParse` returns non-null for junk like 'your Supabase URL', so the
    // shape has to be checked explicitly rather than relying on a null result.
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      return ConfigStatus.malformedUrl;
    }

    return ConfigStatus.ok;
  }
}

/// Why the app can or cannot talk to Supabase.
enum ConfigStatus {
  ok,
  missingUrl,
  missingAnonKey,
  malformedUrl;

  String get message => switch (this) {
    ConfigStatus.ok => 'Supabase configuration is valid.',
    ConfigStatus.missingUrl => 'SUPABASE_URL was not provided at build time.',
    ConfigStatus.missingAnonKey =>
      'SUPABASE_ANON_KEY was not provided at build time.',
    ConfigStatus.malformedUrl =>
      'SUPABASE_URL is not a valid https:// project URL.',
  };
}
