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
  ScreenRecordingStore({this.populated = true});
  final saved = ObdRecording(
    id: 1,
    vehicleName: 'Synthetic Fixture',
    startedAt: DateTime.utc(2026),
    endedAt: DateTime.utc(2026, 1, 1, 0, 1),
    sampleCount: 2,
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
  }) async => afterId == 0
      ? [
          RecordedObdSample(1, fixtureSample(0)),
          RecordedObdSample(2, fixtureSample(1)),
        ]
      : [];
  @override
  Future<List<RecordedObdSample>> chartSamples(
    int sessionId,
    ObdParameter parameter, {
    int limit = 600,
  }) async => parameter == ObdParameter.rpm ? await samples(sessionId) : [];
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
}
