import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/branding/streak_mark.dart';

/// Renders the launcher icons from [StreakMarkPainter].
///
/// A generator, not a test. It runs through `flutter test` because that is the
/// only way to get a real `dart:ui` canvas without adding an image library, but
/// it lives outside `test/` so a bare `flutter test` never scans it — a
/// generator that rewrites checked-in assets has no business running in CI.
///
/// Regenerate with:
///
///   flutter test tool/generate_launcher_icons.dart
///
/// Drawing them from the same painter the splash screen uses is the point: an
/// exported asset drifts from the app the first time someone tweaks one of them.
void main() {
  const androidSizes = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  Future<Uint8List> render(int pixels) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const StreakMarkPainter().paint(
      canvas,
      Size(pixels.toDouble(), pixels.toDouble()),
    );
    final image = await recorder.endRecording().toImage(pixels, pixels);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  test('writes Android launcher icons', () async {
    for (final entry in androidSizes.entries) {
      final bytes = await render(entry.value);
      final file = File(
        'android/app/src/main/res/${entry.key}/ic_launcher.png',
      );
      file.writeAsBytesSync(bytes);
      expect(file.lengthSync(), greaterThan(0));
    }
  });

  test('writes iOS app icons', () async {
    // Only the sizes already present in the asset catalogue are replaced;
    // adding entries would mean editing Contents.json too.
    final dir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
    if (!dir.existsSync()) return;

    final pattern = RegExp(r'Icon-App-(\d+)x\d+@(\d)x\.png');
    for (final file in dir.listSync().whereType<File>()) {
      final match = pattern.firstMatch(file.uri.pathSegments.last);
      if (match == null) continue;
      final points = int.parse(match.group(1)!);
      final scale = int.parse(match.group(2)!);
      file.writeAsBytesSync(await render(points * scale));
    }
    expect(dir.listSync().whereType<File>(), isNotEmpty);
  });
}
