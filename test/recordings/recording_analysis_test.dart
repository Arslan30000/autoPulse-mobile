import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_analysis.dart';

import 'fixtures.dart';

void main() {
  sqfliteFfiInit();
  late SqliteObdRecordingRepository store;
  setUp(
    () => store = SqliteObdRecordingRepository(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      owner: () => null,
    ),
  );
  tearDown(() => store.close());

  test('quality metrics span every page and retain invalid attempts', () async {
    final id = await store.start(fixtureVehicle, fixtureDevice);
    for (var i = 0; i < 501; i++) {
      await store.append(
        id,
        fixtureSample(
          i,
          status: i == 300 ? ObdSampleStatus.noData : ObdSampleStatus.valid,
        ),
      );
    }
    final quality = (await analyzeRecording(store, id))[ObdParameter.rpm]!;
    expect(quality.total, 501);
    expect(quality.valid, 500);
    expect(quality.counts[ObdSampleStatus.noData], 1);
    expect(quality.observedHz, 1);
    expect(quality.meanLatencyMs, 100);
    expect(quality.longestGap, const Duration(seconds: 1));
    expect(
      await store.chartSamples(id, ObdParameter.rpm, limit: 20),
      hasLength(20),
    );
  });

  test(
    'clock reversals and single readings do not produce a fictitious rate',
    () {
      final quality = PidQuality()..add(fixtureSample(5));
      expect(quality.observedHz, isNull);
      quality.add(fixtureSample(4));
      expect(quality.clockDiscontinuities, 1);
      expect(quality.observedHz, isNull);
    },
  );

  test('CSV streams all pages with UTC timestamps, original units, and empty missing values', () async {
    final id = await store.start(fixtureVehicle, fixtureDevice);
    for (var i = 0; i < 251; i++) {
      await store.append(id, fixtureSample(i));
    }
    await store.append(id, fixtureSample(251, status: ObdSampleStatus.noData));
    await store.finish(id);
    final chunks = <String>[];
    await exportRecordingCsv(
      store,
      await store.recording(id),
      (chunk) async => chunks.add(chunk),
    );
    expect(chunks.length, 3);
    final lines = chunks.join().trim().split('\n');
    expect(lines.length, 253);
    expect(lines.last, contains('"Engine RPM",,"rpm","noData"'));
    expect(lines[1], contains('"2026-01-01T00:00:00.000Z"'));
    expect(lines[1], contains(',100,"7E8"'));
  });

  test('CSV quotes delimiters and neutralizes text formulas without changing numbers', () {
    expect(csvCell('car,"name"\nnext'), '"car,""name""\nnext"');
    expect(csvCell('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
    expect(csvCell(-12.5), '-12.5');
    expect(csvCell(null), '');
  });
}
