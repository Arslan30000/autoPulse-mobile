import 'dart:ui' as ui;

import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/widgets/telemetry_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
    'needle parks offline, animates with readings, and clamps the dial',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      Future<void> show(double? value) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 300,
                child: TelemetryGauge(
                  label: 'Speed',
                  unit: 'km/h',
                  value: value,
                  maximum: 240,
                  quality: value == null ? 'Disconnected' : 'Live',
                ),
              ),
            ),
          ),
        );
      }

      Future<Color> dialPixel(int x, int y) async {
        return (await tester.runAsync(() async {
          final gauge = find.byType(TelemetryGauge);
          final paint = tester.widget<CustomPaint>(
            find
                .descendant(of: gauge, matching: find.byType(CustomPaint))
                .first,
          );
          final recorder = ui.PictureRecorder();
          paint.painter!.paint(Canvas(recorder), const Size(300, 300));
          final picture = recorder.endRecording();
          final image = await picture.toImage(300, 300);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final i = (y * 300 + x) * 4;
          final color = Color.fromARGB(
            data.getUint8(i + 3),
            data.getUint8(i),
            data.getUint8(i + 1),
            data.getUint8(i + 2),
          );
          image.dispose();
          picture.dispose();
          return color;
        }))!;
      }

      await show(null);
      expect(await dialPixel(125, 175), AppColors.textTertiary);
      expect(find.text('--'), findsOneWidget);
      await show(120);
      await tester.pump(const Duration(milliseconds: 100));
      expect(await dialPixel(150, 125), isNot(AppColors.primary));
      await tester.pumpAndSettle();
      expect(await dialPixel(150, 125), AppColors.primary);
      await show(300);
      await tester.pumpAndSettle();
      expect(await dialPixel(175, 175), AppColors.primary);
      await show(null);
      await tester.pumpAndSettle();
      expect(await dialPixel(125, 175), AppColors.textTertiary);
      expect(tester.takeException(), isNull);
    },
  );
}
