import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/diagnostics/vehicle_diagnostics.dart';
import 'package:autopulse_ai/services/driving_context/context_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test('automatic backlog uses only clean drives and separates vehicles and owners', () async {
    var owner = 'owner-a';
    final store = SqliteObdRecordingRepository(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      owner: () => owner,
    );
    addTearDown(store.close);
    final pipeline = VehicleDiagnostics(
      store,
      owner: () => owner,
      contextOverride: const RulesContextEvaluator(),
    );
    addTearDown(pipeline.dispose);

    Future<int> record(
      String car,
      double maf, {
      Map<String, dynamic>? scan,
    }) async {
      final id = await store.start(
        Vehicle(id: car, make: 'Test', model: car, year: 2026),
        const ObdDevice(name: 'Fixture', address: '00:11:22:33:44:55'),
      );
      final db = await store.database;
      final batch = db.batch();
      for (var i = 0; i < 180; i++) {
        for (final entry in {
          ObdParameter.rpm: 900,
          ObdParameter.speed: 0,
          ObdParameter.load: 30,
          ObdParameter.throttle: 8,
          ObdParameter.maf: maf,
        }.entries) {
          final at = DateTime.utc(2026, 1, 1, 0, 0, i).toIso8601String();
          batch.insert('samples', {
            'session_id': id,
            'pid': entry.key.pid,
            'value': entry.value,
            'unit': entry.key.unit,
            'quality': 'valid',
            'requested_at': at,
            'received_at': at,
            'latency_ms': 0,
          });
        }
      }
      await batch.commit(noResult: true);
      if (scan != null) await pipeline.attachScan(id, scan);
      await store.finish(id);
      return id;
    }

    final unknown = await record('car-a', 3);
    final fault = await record(
      'car-a',
      15,
      scan: {
        'complete': true,
        'blocked': true,
        'codes': [
          {
            'code': 'P0101',
            'status': 'Stored',
            'scan_time': '2026-01-01T00:00:00Z',
          },
        ],
      },
    );
    await pipeline.refresh();
    expect((await pipeline.result(unknown))?['dtc_gate'], 'unverified');
    final recorded = (await pipeline.result(unknown))?['checks']['16'];
    expect(recorded['scored'], 0);
    expect(recorded['ranges']['idling:ordinary:initial']['low'], 3);
    expect(recorded['ranges']['idling:ordinary:initial']['high'], 3);
    expect(recorded['reference_ranges'], isEmpty);
    expect((await pipeline.result(fault))?['dtc_gate'], 'fault');
    expect(
      await (await store.database).query('diagnostic_references'),
      isEmpty,
    );

    final clean = await record(
      'car-a',
      3,
      scan: {'complete': true, 'blocked': false},
    );
    await pipeline.evaluate(clean);
    await pipeline.refresh();
    expect((await pipeline.result(clean))?['reference'], true);
    expect((await pipeline.result(unknown))?['status'], 'Checked');
    final faultResult = (await pipeline.result(fault))!;
    expect(faultResult['reference'], false);
    expect(faultResult['events'], isNotEmpty);
    expect(
      faultResult['events'][0]['related_session_codes'][0]['code'],
      'P0101',
    );

    final other = await record('car-b', 12);
    await pipeline.refresh();
    expect((await pipeline.result(other))?['model_version'], 0);
    final summary = (await pipeline.healthSummary('car-a'))!;
    expect(summary['reference_version'], 1);
    expect(summary['saved'], 3);
    expect(summary['checked'], 2);
    expect(summary['findings'], isNotEmpty);
    final range = summary['contexts']['idling:ordinary:initial']['16'];
    expect(range['low'], 3);
    expect(range['high'], 15);
    expect(range['drives'], 3);
    owner = 'owner-b';
    expect(await pipeline.result(clean), isNull);
    expect(await pipeline.visibleRecordings(0), isEmpty);
    expect((await pipeline.healthSummary('car-a'))?['saved'], 0);
  });
}
