import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:autopulse_ai/main.dart';

void main() {
  testWidgets('app uses the AutoPulse_ai title', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const AutoPulseApp());
    // Finish the splash delay and onboarding animations so no timers remain.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(seconds: 1));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'AutoPulse_ai');
    expect(find.text('Know Your Vehicle'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
