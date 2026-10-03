import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart assertions run in the test environment', () {
    var assertionRan = false;
    assert(() {
      assertionRan = true;
      return true;
    }());

    expect(assertionRan, isTrue);
  });

  testWidgets('a basic Flutter widget mounts', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Smoke test ready'))),
    );

    expect(find.text('Smoke test ready'), findsOneWidget);
  });
}
