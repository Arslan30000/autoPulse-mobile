import 'dart:ui' as ui;

import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/widgets/telemetry_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  for (final dial in [
    ('RPM', 'rpm', 0.0, 8000.0),
    ('Speed', 'km/h', 0.0, 240.0),
    ('Coolant', '°C', -40.0, 160.0),
  ]) {
    testWidgets(
      '${dial.$1} needle matches the minimum, quarter, midpoint and maximum scale',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        const positions = [
          (0.0, 125, 175),
          (.25, 118, 137),
          (.5, 150, 115),
          (.75, 182, 137),
          (1.0, 175, 175),
        ];
        for (final position in positions) {
          final value = dial.$3 + (dial.$4 - dial.$3) * position.$1;
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox(
                  width: 300,
                  child: TelemetryGauge(
                    label: dial.$1,
                    unit: dial.$2,
                    value: value,
                    minimum: dial.$3,
                    maximum: dial.$4,
                    quality: 'Live',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(value.round().toString()), findsOneWidget);
          final pixel = await _dialPixel(tester, position.$2, position.$3);
          expect(
            pixel,
            AppColors.primary,
            reason:
                '${dial.$1} at $value must point to ${position.$1 * 100}% of the dial',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final value in [double.nan, double.infinity, double.negativeInfinity]) {
    testWidgets('non-finite reading $value displays missing data safely', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 250,
              child: TelemetryGauge(
                label: 'RPM',
                unit: 'rpm',
                value: value,
                maximum: 8000,
                quality: 'Invalid response',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('--'), findsOneWidget);
    });
  }
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

Future<Color> _dialPixel(WidgetTester tester, int x, int y) async =>
    (await tester.runAsync(() async {
      final paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(TelemetryGauge),
              matching: find.byType(CustomPaint),
            )
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
