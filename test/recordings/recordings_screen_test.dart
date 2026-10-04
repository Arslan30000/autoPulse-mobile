import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/screens/history/recordings_screen.dart';

import 'fixtures.dart';

// Database correctness is exercised separately with real SQLite. UI tests use
// deterministic futures so widget animations do not race a native worker isolate.
class ScreenRecordingStore implements RecordingStore {
  final bool populated;
  final int rowCount;
  ScreenRecordingStore({this.populated = true, this.rowCount = 2});
  ObdRecording get saved => ObdRecording(
    id: 1,
    vehicleName: 'Synthetic Fixture',
    startedAt: DateTime.utc(2026),
    endedAt: DateTime.utc(2026, 1, 1, 0, 1),
    sampleCount: rowCount,
    cloudId: 'synthetic-recording',
    adapterName: 'Synthetic adapter',
  );
  @override
  Future<List<ObdRecording>> listRecordings(
    String? owner, {
    int beforeId = 0,
    int limit = 50,
  }) async => populated ? [saved] : [];
  @override
  Future<ObdRecording> recording(int id) async => saved;
  @override
  Future<List<RecordedObdSample>> samples(
    int sessionId, {
    int afterId = 0,
    int limit = 250,
  }) async => [
    for (var i = afterId; i < rowCount && i < afterId + limit; i++)
      RecordedObdSample(i + 1, fixtureSample(i)),
  ];
  @override
  Future<List<RecordedObdSample>> chartSamples(
    int sessionId,
    ObdParameter parameter, {
    int limit = 600,
    int beforeId = 0,
  }) async {
    if (parameter != ObdParameter.rpm) return [];
    final end = beforeId == 0 ? rowCount : beforeId - 1;
    final start = (end - limit).clamp(0, rowCount);
    return [
      for (var i = start; i < end; i++)
        RecordedObdSample(i + 1, fixtureSample(i)),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'recording history opens details without cloud or adapter access',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RecordingsScreen(store: ScreenRecordingStore())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Fixture'), findsOneWidget);
      await tester.tap(find.text('Synthetic Fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Recording details'), findsOneWidget);
      expect(find.byTooltip('Export CSV'), findsOneWidget);
      expect(find.textContaining('2/2 valid samples'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('empty recording history gives a useful next action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordingsScreen(store: ScreenRecordingStore(populated: false)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No recordings yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'upload stays discoverable in local builds and explains missing setup',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RecordingsScreen(store: ScreenRecordingStore())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload trip to Supabase'));
      await tester.pumpAndSettle();
      expect(find.text('Cloud upload unavailable'), findsOneWidget);
      expect(
        find.textContaining('recording is saved on this phone'),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic Fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Upload trip to Supabase'), findsOneWidget);
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .join('\n');
      expect(text, isNot(matches(r'[\u00c2\u00c3\u00e2\ufffd]')));
      expect(text, isNot(contains('00:00:00.000')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'earlier graph windows retain full-session quality and trip time',
    (tester) async {
      final store = ScreenRecordingStore(rowCount: 661);
      await tester.pumpWidget(
        MaterialApp(
          home: RecordingDetailsScreen(store: store, recording: store.saved),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('661/661 valid samples'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('View earlier readings'), 200);
      await tester.tap(find.text('View earlier readings'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Earlier 61 readings.'), findsOneWidget);
      expect(find.text('View earlier readings'), findsNothing);
      await tester.ensureVisible(find.text('Return to latest readings'));
      await tester.tap(find.text('Return to latest readings'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Latest 600 readings.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
