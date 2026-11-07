import 'package:autopulse_ai/core/widgets/report_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  testWidgets(
    'report preview opens and sharing passes its exact content to the platform',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return 'shared';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReportActions(
              title: 'Sample report',
              content: 'SAMPLE DATA\nRPM: 1726',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Detailed Report'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('SAMPLE DATA\nRPM: 1726'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share Report'));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'share');
      expect(calls.single.arguments['text'], 'SAMPLE DATA\nRPM: 1726');
      expect(calls.single.arguments['subject'], 'Sample report');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a share error is actionable and does not crash the screen', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'UNAVAILABLE'),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportActions(title: 'Sample report', content: 'SAMPLE DATA'),
        ),
      ),
    );
    await tester.tap(find.text('Share Report'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sharing is unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
