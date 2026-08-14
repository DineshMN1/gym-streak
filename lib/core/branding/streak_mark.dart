import 'package:flutter/material.dart';
import 'package:gym_streak/core/theme/app_theme.dart';

/// The Gym Streak mark: a contribution grid with a rising diagonal.
///
/// The obvious choice for a streak app is a flame, which is also what Duolingo,
/// Snapchat and every habit tracker already use — it says "streak" and nothing
/// about *this* app. The contribution heatmap is the thing that makes this app
/// recognisable, so the mark is built from it: nine cells, three of them lit
/// along an ascending diagonal, in the same green ramp the heatmap itself uses.
///
/// It reads as an upward climb at a glance and as a contribution graph on
/// inspection, and it says the app's own tagline — never break the chain —
/// without drawing a chain.
///
/// A 3×3 grid rather than the heatmap's true density is deliberate: at a 48px
/// launcher size anything finer turns to mush.
///
/// Drawn in code rather than shipped as an asset so the splash screen and the
/// launcher icons come from one definition — see
/// `test/tool/generate_launcher_icons_test.dart`, which renders these same
/// instructions to PNG.
class StreakMarkPainter extends CustomPainter {
  const StreakMarkPainter({this.includeBackground = true});

  /// Launcher icons need their own ground; the splash screen already has one.
  final bool includeBackground;

  /// Which cells are lit, and how brightly. Row 0 is the top.
  static const List<({int row, int col, Color color})> _litCells = [
    (row: 2, col: 0, color: AppColors.heatmapLevel2),
    (row: 1, col: 1, color: AppColors.heatmapLevel3),
    (row: 0, col: 2, color: AppColors.heatmapLevel4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final rect = Rect.fromLTWH(0, 0, side, side);

    if (includeBackground) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(side * 0.22)),
        Paint()..color = AppColors.background,
      );
    }

    // Proportional so the mark is identical at 48px and 1024px.
    const grid = 3;
    final padding = side * 0.18;
    final available = side - padding * 2;
    final gap = available * 0.10;
    final cell = (available - gap * (grid - 1)) / grid;
    final radius = Radius.circular(cell * 0.26);

    final dim = Paint()..color = AppColors.heatmapEmpty;
    for (var row = 0; row < grid; row++) {
      for (var col = 0; col < grid; col++) {
        final lit = _litCells
            .where((c) => c.row == row && c.col == col)
            .firstOrNull;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              padding + col * (cell + gap),
              padding + row * (cell + gap),
              cell,
              cell,
            ),
            radius,
          ),
          lit == null ? dim : (Paint()..color = lit.color),
        );
      }
    }
  }

  @override
  bool shouldRepaint(StreakMarkPainter oldDelegate) =>
      oldDelegate.includeBackground != includeBackground;
}

/// The mark, sized to [size].
class StreakMark extends StatelessWidget {
  const StreakMark({super.key, this.size = 96, this.includeBackground = false});

  final double size;
  final bool includeBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: StreakMarkPainter(includeBackground: includeBackground),
        isComplex: false,
        // The mark carries the app's identity, so give it a name rather than
        // letting a screen reader announce nothing.
        child: Semantics(label: 'Gym Streak', child: SizedBox.expand()),
      ),
    );
  }
}
