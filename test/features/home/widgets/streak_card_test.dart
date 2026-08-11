import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/features/home/providers/workout_provider.dart';
import 'package:gym_streak/features/home/widgets/streak_card.dart';

import '../../../support/fixtures.dart';
import '../../../support/harness.dart';

void main() {
  setUpAll(configureTestFonts);

  testWidgets('renders current streak, best streak and total from logs', (
    tester,
  ) async {
    // Three consecutive days ending today, plus an isolated day 10 days back:
    //   current = 3, best = 3, total = 4 distinct days.
    final logs = logsForDaysAgo([0, 1, 2, 10]);

    await tester.pumpAppWidget(
      const StreakCard(),
      overrides: [
        workoutLogsProvider.overrideWith((ref) => Stream.value(logs)),
      ],
    );

    expect(find.text('Best Streak'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('day streak'), findsOneWidget);
    // '3' appears twice: the big current-streak number and the best-streak stat.
    expect(find.text('3'), findsNWidgets(2));
    // '4' appears once: the total stat.
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('renders zeros when there are no logs', (tester) async {
    await tester.pumpAppWidget(
      const StreakCard(),
      overrides: [workoutLogsProvider.overrideWith((ref) => Stream.value([]))],
    );

    expect(find.text('0'), findsNWidgets(3));
  });
}
