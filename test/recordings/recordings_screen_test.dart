import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/core/widgets/obd_telemetry_chart.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/screens/history/recordings_screen.dart';
import 'package:autopulse_ai/services/account_data_service.dart';

import 'fixtures.dart';

// Database correctness is exercised separately with real SQLite. UI tests use
// deterministic futures so widget animations do not race a native worker isolate.
class ScreenRecordingStore implements RecordingStore {
  bool populated;
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
    RecordingSortField sortBy = RecordingSortField.date,
    bool ascending = false,
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

class SortingScreenRecordingStore extends ScreenRecordingStore {
  final calls = <({RecordingSortField field, bool ascending, int beforeId})>[];
  Completer<List<ObdRecording>>? nextResponse;
  final runs = [
    ObdRecording(
      id: 10,
      vehicleName: 'Newest short trip',
      startedAt: DateTime.utc(2026, 11, 14),
      endedAt: DateTime.utc(2026, 11, 14, 0, 2),
      sampleCount: 2,
    ),
    ObdRecording(
      id: 20,
      vehicleName: 'Older long trip',
      startedAt: DateTime.utc(2026, 11, 13),
      endedAt: DateTime.utc(2026, 11, 13, 1),
      sampleCount: 2,
    ),
  ];
  @override
  Future<List<ObdRecording>> listRecordings(
    String? owner, {
    int beforeId = 0,
    int limit = 50,
    RecordingSortField sortBy = RecordingSortField.date,
    bool ascending = false,
  }) async {
    calls.add((field: sortBy, ascending: ascending, beforeId: beforeId));
    final blocked = nextResponse;
    nextResponse = null;
    if (blocked != null) return blocked.future;
    final sorted = [...runs]
      ..sort((a, b) {
        final comparison = sortBy == RecordingSortField.date
            ? a.startedAt.compareTo(b.startedAt)
            : a.duration!.compareTo(b.duration!);
        return ascending ? comparison : -comparison;
      });
    return sorted;
  }
}

class _MixedPidStore extends ScreenRecordingStore {
  _MixedPidStore() : super(rowCount: 20136);

  @override
  Future<List<RecordedObdSample>> chartSamples(
    int sessionId,
    ObdParameter parameter, {
    int limit = 600,
    int beforeId = 0,
  }) async {
    final parameterIndex = ObdParameter.values.indexOf(parameter);
    if (parameterIndex >= 4) return [];
    final rows = <RecordedObdSample>[];
    for (var i = 0; i < 5034; i++) {
      final id = i * 4 + parameterIndex + 1;
      if (beforeId != 0 && id >= beforeId) break;
      final time = DateTime.utc(2026).add(Duration(milliseconds: i * 800));
      rows.add(
        RecordedObdSample(
          id,
          ObdSample(
            parameter: parameter,
            value: (i % 100).toDouble(),
            status: ObdSampleStatus.valid,
            requestedAt: time,
            receivedAt: time,
            latencyMs: 0,
          ),
        ),
      );
    }
    return rows.skip((rows.length - limit).clamp(0, rows.length)).toList();
  }
}

void main() {
  void showBothRows(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> choose(WidgetTester tester, String key, String value) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  testWidgets('saved runs default to newest and expose all sort choices', (
    tester,
  ) async {
    showBothRows(tester);
    final store = SortingScreenRecordingStore();
    await tester.pumpWidget(MaterialApp(home: RecordingsScreen(store: store)));
    await tester.pumpAndSettle();
    expect(store.calls.last, (
      field: RecordingSortField.date,
      ascending: false,
      beforeId: 0,
    ));
    expect(find.text('Newest first'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Newest short trip')).dy,
      lessThan(tester.getTopLeft(find.text('Older long trip')).dy),
    );
    expect(find.text('Duration 00:02:00'), findsOneWidget);
    await choose(tester, 'recording-sort-field', 'Duration');
    expect(store.calls.last, (
      field: RecordingSortField.duration,
      ascending: false,
      beforeId: 0,
    ));
    expect(
      tester.getTopLeft(find.text('Older long trip')).dy,
      lessThan(tester.getTopLeft(find.text('Newest short trip')).dy),
    );
    await choose(tester, 'recording-sort-order', 'Ascending');
    expect(store.calls.last, (
      field: RecordingSortField.duration,
      ascending: true,
      beforeId: 0,
    ));
    expect(find.text('Shortest first; unknown durations last'), findsOneWidget);
    await choose(tester, 'recording-sort-field', 'Date');
    expect(store.calls.last, (
      field: RecordingSortField.date,
      ascending: true,
      beforeId: 0,
    ));
    expect(find.text('Oldest first'), findsOneWidget);
    await choose(tester, 'recording-sort-order', 'Descending');
    expect(find.text('Newest first'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh keeps the chosen field and direction', (tester) async {
    final store = SortingScreenRecordingStore();
    await tester.pumpWidget(MaterialApp(home: RecordingsScreen(store: store)));
    await tester.pumpAndSettle();
    await choose(tester, 'recording-sort-field', 'Duration');
    await choose(tester, 'recording-sort-order', 'Ascending');
    final beforeRefresh = store.calls.length;
    await tester.tap(find.byTooltip('Refresh recordings'));
    await tester.pumpAndSettle();
    expect(store.calls.length, greaterThan(beforeRefresh));
    expect(
      store.calls
          .skip(beforeRefresh)
          .every(
            (c) =>
                c.field == RecordingSortField.duration &&
                c.ascending &&
                c.beforeId == 0,
          ),
      isTrue,
    );
  });

  testWidgets('changing sort during a load discards the late old response', (
    tester,
  ) async {
    showBothRows(tester);
    final store = SortingScreenRecordingStore();
    await tester.pumpWidget(MaterialApp(home: RecordingsScreen(store: store)));
    await tester.pumpAndSettle();
    final blocked = Completer<List<ObdRecording>>();
    store.nextResponse = blocked;
    await tester.tap(find.byTooltip('Refresh recordings'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recording-sort-field')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Duration').last);
    await tester.pump(const Duration(milliseconds: 400));
    blocked.complete([
      ObdRecording(
        id: 99,
        vehicleName: 'Stale response',
        startedAt: DateTime.utc(2026),
        endedAt: DateTime.utc(2026),
        sampleCount: 0,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Stale response'), findsNothing);
    expect(store.calls.last.field, RecordingSortField.duration);
    expect(
      tester.getTopLeft(find.text('Older long trip')).dy,
      lessThan(tester.getTopLeft(find.text('Newest short trip')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sort controls remain usable on a narrow phone with larger text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: RecordingsScreen(store: SortingScreenRecordingStore()),
        ),
      );
      await tester.pumpAndSettle();
      await choose(tester, 'recording-sort-field', 'Duration');
      await choose(tester, 'recording-sort-order', 'Ascending');
      expect(
        find.text('Shortest first; unknown durations last'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a completed drive appears while other restores remain active', (
    tester,
  ) async {
    final account = AccountDataService.instance;
    final previous = (
      account.busy,
      account.restoredRuns,
      account.restoredSamples,
      account.restoreTotalSamples,
    );
    final restOfAccount = Completer<void>();
    addTearDown(() {
      if (!restOfAccount.isCompleted) restOfAccount.complete();
      account.busy = previous.$1;
      account.restoredRuns = previous.$2;
      account.restoredSamples = previous.$3;
      account.restoreTotalSamples = previous.$4;
    });
    final store = ScreenRecordingStore(populated: false);
    await tester.pumpWidget(
      MaterialApp(
        home: RecordingsScreen(
          store: store,
          synchronizeAccount: () => restOfAccount.future,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Synthetic Fixture'), findsNothing);

    store.populated = true;
    account.busy = true;
    account.restoredRuns++;
    account.restoredSamples = 500;
    account.restoreTotalSamples = 1000;
    // Simulate a production restore-progress notification without network IO.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    account.notifyListeners();
    await tester.pump();
    expect(find.text('Synthetic Fixture'), findsOneWidget);
    expect(account.busy, isTrue);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );

    restOfAccount.complete();
    account.busy = false;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    account.notifyListeners();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'session totals and per-PID counts stay distinct across all pages',
    (tester) async {
      final store = _MixedPidStore();
      await tester.pumpWidget(
        MaterialApp(
          home: RecordingGraphScreen(store: store, recording: store.saved),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('20136 total PID readings across all parameters'),
        findsOneWidget,
      );
      expect(
        find.text('5034 readings across the full session for Engine RPM'),
        findsOneWidget,
      );
      var chart = tester.widget<ObdTelemetryChart>(
        find.byType(ObdTelemetryChart),
      );
      expect(chart.samples, hasLength(5034));
      expect(chart.samples.first.receivedAt, DateTime.utc(2026));
      expect(
        chart.samples.last.receivedAt,
        DateTime.utc(2026).add(const Duration(milliseconds: 5033 * 800)),
      );
      await tester.tap(find.byType(DropdownButtonFormField<ObdParameter>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vehicle speed (km/h)').last);
      await tester.pumpAndSettle();
      chart = tester.widget<ObdTelemetryChart>(find.byType(ObdTelemetryChart));
      expect(chart.samples, hasLength(5034));
      expect(
        chart.samples.every((sample) => sample.parameter == ObdParameter.speed),
        isTrue,
      );
      expect(
        find.text('5034 readings across the full session for Vehicle speed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening recordings restores cloud runs before showing an empty history',
    (tester) async {
      final store = ScreenRecordingStore(populated: false);
      var restores = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RecordingsScreen(
            store: store,
            synchronizeAccount: () async {
              restores++;
              store.populated = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(restores, 1);
      expect(find.text('Synthetic Fixture'), findsOneWidget);
      expect(find.textContaining('No recordings yet.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'refresh downloads cloud history instead of only reloading SQLite',
    (tester) async {
      final store = ScreenRecordingStore(populated: false);
      var restores = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RecordingsScreen(
            store: store,
            synchronizeAccount: () async {
              restores++;
              if (restores > 1) store.populated = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No recordings yet.'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh recordings'));
      await tester.pumpAndSettle();
      expect(restores, 2);
      expect(find.text('Synthetic Fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cloud restore failure keeps local runs visible and exposes retry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecordingsScreen(
            store: ScreenRecordingStore(),
            synchronizeAccount: () async =>
                throw StateError('Network unavailable'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Fixture'), findsOneWidget);
      expect(find.textContaining('Cloud restore failed.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
      expect(find.textContaining('2/2 valid ·'), findsOneWidget);
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

  testWidgets('recording details open a dedicated full-session graph', (
    tester,
  ) async {
    final store = ScreenRecordingStore(rowCount: 661);
    await tester.pumpWidget(
      MaterialApp(
        home: RecordingDetailsScreen(store: store, recording: store.saved),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('661/661 valid ·'), findsOneWidget);
    expect(find.text('Explore telemetry graphs'), findsOneWidget);
    expect(find.textContaining('Latest 600 readings.'), findsNothing);
    await tester.tap(find.text('Explore telemetry graphs'));
    await tester.pumpAndSettle();
    expect(find.text('Telemetry graph'), findsOneWidget);
    expect(
      find.textContaining('661 readings across the full session'),
      findsOneWidget,
    );
    expect(find.text('Recorded parameter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
