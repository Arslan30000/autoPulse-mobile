import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';

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

  test('SQLite round trip preserves timestamps, nulls, source, and paginated ordering', () async {
    final id = await store.start(fixtureVehicle, fixtureDevice);
    await store.append(id, fixtureSample(0));
    await store.append(id, fixtureSample(1, status: ObdSampleStatus.noData));
    await store.append(id, fixtureSample(2));
    await store.finish(id);
    final first = await store.samples(id, limit: 2);
    final second = await store.samples(id, afterId: first.last.id, limit: 2);
    expect(first.length, 2);
    expect(second.length, 1);
    expect(second.first.id, greaterThan(first.last.id));
    expect(first.first.sample.source, '7E8');
    expect(first.first.sample.requestedAt, fixtureSample(0).requestedAt);
    expect(first.last.sample.value, isNull);
    expect(first.last.sample.status, ObdSampleStatus.noData);
    final recording = await store.recording(id);
    expect(recording.sampleCount, 3);
    expect(recording.cloudId, isNotEmpty);
    expect(recording.vehicle!.id, isNotEmpty);
    expect(recording.endedAt, isNotNull);
    expect((await store.recording(id)).cloudId, recording.cloudId);
    expect(() => store.append(id, fixtureSample(3)), throwsStateError);
  });

  test(
    'ownership is bound once and other accounts cannot claim or list it',
    () async {
      final id = await store.start(fixtureVehicle, fixtureDevice);
      expect(() => store.claimCompleted(id, 'owner-a'), throwsStateError);
      await store.append(id, fixtureSample(0));
      await store.append(id, fixtureSample(1));
      await store.finish(id);
      await store.claimCompleted(id, 'owner-a');
      expect(await store.listRecordings('owner-b'), isEmpty);
      expect(await store.listRecordings(null), isEmpty);
      expect(await store.listRecordings('owner-a'), hasLength(1));
      expect(() => store.claimCompleted(id, 'owner-b'), throwsStateError);
      expect(() => store.checkpoint(id, 'owner-b', 10), throwsStateError);
      await store.checkpoint(id, 'owner-a', 2);
      expect(() => store.checkpoint(id, 'owner-a', 1), throwsStateError);
    },
  );

  test(
    'invalid measurements and unbounded page requests are rejected',
    () async {
      final id = await store.start(fixtureVehicle, fixtureDevice);
      final valid = fixtureSample(0);
      final invalid = ObdSample(
        parameter: valid.parameter,
        value: double.nan,
        status: valid.status,
        requestedAt: valid.requestedAt,
        receivedAt: valid.receivedAt,
        latencyMs: 0,
      );
      expect(() => store.append(id, invalid), throwsArgumentError);
      expect(() => store.samples(id, limit: 0), throwsArgumentError);
      expect(() => store.samples(id, limit: 1001), throwsArgumentError);
    },
  );

  test(
    'offline vehicle identity remains reusable after assigning a recording',
    () async {
      final vehicle = fixtureVehicle.copyWith(id: 'synthetic-local-id');
      final first = await store.start(vehicle, fixtureDevice);
      await store.finish(first);
      final assigned = await store.claimCompleted(first, 'owner-a');
      final second = await store.start(vehicle, fixtureDevice);
      await store.finish(second);
      expect((await store.recording(second)).ownerId, isNull);
      expect(
        (await store.recording(second)).vehicle!.id,
        isNot(assigned.vehicle!.id),
      );
      final sameAccount = await store.claimCompleted(second, 'owner-a');
      expect(sameAccount.vehicle!.id, assigned.vehicle!.id);
      final third = await store.start(vehicle, fixtureDevice);
      await store.finish(third);
      final otherAccount = await store.claimCompleted(third, 'owner-b');
      expect(otherAccount.vehicle!.id, isNot(assigned.vehicle!.id));
      expect(() => store.claimCompleted(first, 'owner-b'), throwsStateError);
    },
  );

  test(
    'v1 schema migration preserves legacy samples and adds stable identifiers',
    () async {
      await store.close();
      final directory = await Directory.systemTemp.createTemp('obd-migration-');
      addTearDown(() => directory.delete(recursive: true));
      final file = path.join(directory.path, 'recordings.db');
      final old = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: true,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'vehicle_name TEXT NOT NULL, vehicle_year INTEGER NOT NULL, adapter_name TEXT NOT NULL, '
              'started_at TEXT NOT NULL, ended_at TEXT)',
            );
            await db.execute(
              'CREATE TABLE samples (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'session_id INTEGER NOT NULL REFERENCES sessions(id), pid INTEGER NOT NULL, '
              'value REAL, unit TEXT NOT NULL, quality TEXT NOT NULL, requested_at TEXT NOT NULL, '
              'received_at TEXT NOT NULL, latency_ms INTEGER NOT NULL, ecu_source TEXT)',
            );
          },
        ),
      );
      await old.insert('sessions', {
        'vehicle_name': 'Legacy car',
        'vehicle_year': 2020,
        'adapter_name': 'Adapter',
        'started_at': '2026-01-01T00:00:00Z',
      });
      await old.insert('samples', {
        'session_id': 1,
        'pid': 12,
        'value': 1500.0,
        'unit': 'rpm',
        'quality': 'valid',
        'requested_at': '2026-01-01T00:00:01Z',
        'received_at': '2026-01-01T00:00:01.100Z',
        'latency_ms': 100,
        'ecu_source': '7E8',
      });
      await old.close();
      store = SqliteObdRecordingRepository(
        factory: databaseFactoryFfi,
        databasePath: file,
        owner: () => null,
      );
      final migrated = await store.recording(1);
      expect(migrated.vehicleName, 'Legacy car');
      expect(migrated.vehicle!.make, 'Unknown');
      expect(migrated.cloudId, isNotEmpty);
      expect(migrated.endedAt, isNull);
      expect(migrated.sampleCount, 1);
      expect((await store.samples(1)).single.sample.value, 1500);
      await store.finish(1);
      await store.claimCompleted(1, 'owner-a');
      await store.checkpoint(1, 'owner-a', 1);
      await store.setSyncState(1, 'owner-a', RecordingSyncState.uploading);
      await store.close();
      store = SqliteObdRecordingRepository(
        factory: databaseFactoryFfi,
        databasePath: file,
        owner: () => 'owner-a',
      );
      final reopened = await store.recording(1);
      expect(reopened.cloudId, migrated.cloudId);
      expect(reopened.uploadedSampleId, 1);
      expect(reopened.syncState, RecordingSyncState.uploading);
      await store.close();
    },
  );
}
