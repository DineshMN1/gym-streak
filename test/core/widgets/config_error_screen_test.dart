import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/widgets/config_error_screen.dart';
import 'package:gym_streak/supabase_config.dart';

import '../../support/harness.dart';

void main() {
  setUpAll(configureTestFonts);

  testWidgets('explains a missing URL and shows the fix', (tester) async {
    await tester.pumpAppWidget(
      const ConfigErrorScreen(status: ConfigStatus.missingUrl),
    );

    expect(find.text('Configuration required'), findsOneWidget);
    expect(find.text(ConfigStatus.missingUrl.message), findsOneWidget);
    expect(find.text(SupabaseConfig.runCommand), findsOneWidget);
  });

  testWidgets('explains a malformed URL', (tester) async {
    await tester.pumpAppWidget(
      const ConfigErrorScreen(status: ConfigStatus.malformedUrl),
    );

    expect(find.text(ConfigStatus.malformedUrl.message), findsOneWidget);
  });
}
