// Export the shared vector identity before running flutter_launcher_icons:
// flutter test tool/export_brand_assets.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export brand assets from the app vector', () async {
    Future<void> export(
      String path, {
      required bool background,
      required double scale,
    }) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 1024.0;
      if (background) {
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, size, size),
          Paint()..color = AppColors.background,
        );
      }
      final extent = size * scale;
      canvas.translate((size - extent) / 2, (size - extent) / 2);
      const BrandEmblemPainter().paint(canvas, Size.square(extent));
      final picture = recorder.endRecording();
      final image = await picture.toImage(1024, 1024);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(path).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }

    await export('assets/app_icon.png', background: true, scale: .78);
    await export(
      'assets/branding/app-icon-foreground.png',
      background: false,
      scale: .78,
    );
  });
}
