// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autopulse_ai/main.dart';

void main() {
  testWidgets('app uses the AutoPulse_ai title', (WidgetTester tester) async {
    await tester.pumpWidget(const AutoPulseApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'AutoPulse_ai');
  });
}
