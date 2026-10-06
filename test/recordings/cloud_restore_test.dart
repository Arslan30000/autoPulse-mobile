import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';

import 'fixtures.dart';

void main() {
  sqfliteFfiInit();
  late SqliteObdRecordingRepository store;
  String? owner;
  setUp(() {
    owner = 'owner-a';
    store = SqliteObdRecordingRepository(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      owner: () => owner,
    );
  });
  tearDown(() => store.close());
  const car = Vehicle(
    id: 'cloud-car',
    ownerId: 'owner-a',
    make: 'Toyota',
    model: 'Yaris',
    year: 2020,
  );
  Map<String, dynamic> session() => {
    'id': 'cloud-run',
    'owner_id': 'owner-a',
    'vehicle_id': car.id,
    'vehicle_name': car.displayName,
    'adapter_name': 'Fixture',
    'started_at': '2026-01-01T00:00:00Z',
    'ended_at': '2026-01-01T00:01:00Z',
    'sample_count': 1,
    'uploaded_at': '2026-01-01T00:02:00Z',
  };
  List<Map<String, dynamic>> samples() => [
    {
      'session_id': 'cloud-run',
      'owner_id': 'owner-a',
      'sample_id': 123,
      'pid': 12,
      'value': 1200.0,
      'unit': 'rpm',
      'quality': 'valid',
      'requested_at': '2026-01-01T00:00:00Z',
      'received_at': '2026-01-01T00:00:00.100Z',
      'latency_ms': 100,
      'ecu_source': '7E8',
    },
  ];
  test(
    'cloud restoration is idempotent and preserves existing offline runs',
    () async {
      owner = null;
      final offline = await store.start(fixtureVehicle, fixtureDevice);
      await store.append(offline, fixtureSample(0));
      await store.finish(offline);
      owner = 'owner-a';
      await store.importCloud(session(), car, samples(), owner!);
      await store.importCloud(session(), car, samples(), owner!);
      final all = await store.listRecordings(owner);
      expect(all, hasLength(2));
      final restored = all.singleWhere((r) => r.cloudId == 'cloud-run');
      expect(restored.syncState, RecordingSyncState.synced);
      expect((await store.samples(restored.id)).single.sample.value, 1200);
      expect((await store.samples(offline)).single.sample.value, 1000);
      owner = 'owner-b';
      expect((await store.listRecordings(owner)).map((r) => r.id), [offline]);
    },
  );
  test('incomplete upload and cross account restoration are rejected without local rows', () async {
    await expectLater(
      store.importCloud(session(), car, [], owner!),
      throwsStateError,
    );
    await expectLater(
      store.importCloud(
        {...session(), 'uploaded_at': null},
        car,
        samples(),
        owner!,
      ),
      throwsStateError,
    );
    owner = 'owner-b';
    await expectLater(
      store.importCloud(session(), car, samples(), 'owner-a'),
      throwsStateError,
    );
    expect(await store.listRecordings(owner), isEmpty);
  });
}
