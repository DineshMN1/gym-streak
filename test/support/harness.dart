import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gym_streak/core/theme/app_theme.dart';

/// Call once per test file, from `setUpAll`.
///
/// [AppTheme.darkTheme] builds its text theme with google_fonts, which fetches
/// Inter over HTTP on first use. `flutter_test` blocks outbound HTTP, so
/// leaving runtime fetching enabled produces noise (and, on some platforms,
/// failures). Disabling it makes google_fonts fall back to the default font.
void configureTestFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

extension PumpAppX on WidgetTester {
  /// Pumps [child] inside the real [AppTheme.darkTheme] and a [ProviderScope].
  ///
  /// Supply fake data through [overrides]. Overriding a provider replaces its
  /// body outright, so widgets under test never reach `Supabase.instance` and
  /// no Supabase initialisation is required.
  Future<void> pumpAppWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: Scaffold(body: child),
        ),
      ),
    );
    // Lets synchronous stream overrides (Stream.value) deliver their first event.
    await pump();
  }
}
