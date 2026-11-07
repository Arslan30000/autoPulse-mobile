import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_chunk_codec.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';

import 'fixtures.dart';

class _ChunkCloud extends SupabaseRecordingRepository {
  final batches = <List<int>>[];
  int completed = 0;
  _ChunkCloud()
    : super(
        SupabaseClient('https://fixture.supabase.co', 'public'),
        compressed: true,
        accountOwner: () => 'owner-a',
      );
  @override
  Future<void> prepare(ObdRecording recording, String owner) async {}
  @override
  Future<void> upload(
    ObdRecording recording,
    String owner,
    List<RecordedObdSample> samples,
  ) async {
    batches.add(samples.map((s) => s.id).toList());
  }

  @override
  Future<void> complete(ObdRecording recording, String owner) async {
    completed++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('compressed chunks preserve null, negative trim, source, units and timestamps exactly', () {
    final rows = [
      SupabaseRecordingRepository.encodeSample(
        'session',
        'owner',
        RecordedObdSample(1, fixtureSample(0)),
      ),
      SupabaseRecordingRepository.encodeSample(
        'session',
        'owner',
        RecordedObdSample(
          2,
          fixtureSample(1, status: ObdSampleStatus.noData),
          storedUnit: 'stored-unit',
        ),
      ),
      {'sample_id': 3, 'value': -7.8125, 'quality': 'valid'},
    ];
    final bytes = RecordingChunkCodec.encode(rows);
    expect(RecordingChunkCodec.encode(rows), bytes);
    expect(
      RecordingChunkCodec.decode(
        bytes,
        expectedChecksum: RecordingChunkCodec.checksum(bytes),
        expectedRows: 3,
      ),
      rows,
    );
  });
  test('corrupt checksum, count mismatch and oversized compressed data are rejected', () {
    final bytes = RecordingChunkCodec.encode([
      {'sample_id': 1},
    ]);
    expect(
      () => RecordingChunkCodec.decode(
        bytes,
        expectedChecksum: 'wrong',
        expectedRows: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => RecordingChunkCodec.decode(
        bytes,
        expectedChecksum: RecordingChunkCodec.checksum(bytes),
        expectedRows: 2,
      ),
      throwsFormatException,
    );
    expect(
      () => RecordingChunkCodec.decode(
        Uint8List(RecordingChunkCodec.maxCompressedBytes + 1),
        expectedChecksum: 'wrong',
        expectedRows: 1,
      ),
      throwsFormatException,
    );
    expect(() => RecordingChunkCodec.encode([]), throwsArgumentError);
  });
  test('decompression limit stops a highly compressed oversized payload', () {
    final bytes = Uint8List.fromList(
      gzip.encode(utf8.encode('x' * (RecordingChunkCodec.maxDecodedBytes + 1))),
    );
    expect(
      () => RecordingChunkCodec.decode(
        bytes,
        expectedChecksum: RecordingChunkCodec.checksum(bytes),
        expectedRows: 1,
      ),
      throwsFormatException,
    );
  });

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
  final car = fixtureVehicle.copyWith(id: 'car-a', ownerId: 'owner-a');
  Map<String, dynamic> session(int count) => {
    'id': 'cloud-session',
    'owner_id': 'owner-a',
    'vehicle_name': car.displayName,
    'adapter_name': 'Fixture',
    'started_at': '2026-01-01T00:00:00Z',
    'ended_at': '2026-01-01T10:00:00Z',
    'uploaded_at': '2026-01-01T10:01:00Z',
    'sample_count': count,
  };
  Map<String, dynamic> row(int i) => SupabaseRecordingRepository.encodeSample(
    'cloud-session',
    'owner-a',
    RecordedObdSample(i + 1, fixtureSample(i)),
  );
  test('interrupted restore stays invisible and resumes from a durable sample cursor', () async {
    Stream<List<Map<String, dynamic>>> interrupted() async* {
      yield [row(0), row(1)];
      throw TimeoutException('Synthetic outage');
    }

    await expectLater(
      store.importCloudPages(session(3), car, interrupted(), owner!),
      throwsA(isA<TimeoutException>()),
    );
    expect(await store.listRecordings(owner), isEmpty);
    expect(await store.restoreCursor(session(3), owner!), 2);
    await store.importCloudPages(
      session(3),
      car,
      Stream.value([row(2)]),
      owner!,
    );
    final restored = (await store.listRecordings(owner)).single;
    expect(restored.sampleCount, 3);
    expect((await store.samples(restored.id)).map((s) => s.sample.value), [
      1000,
      1001,
      1002,
    ]);
    expect(restored.syncState, RecordingSyncState.synced);
  });
  test('restore rejects wrong owners, duplicate IDs and invalid values before publishing a trip', () async {
    await expectLater(
      store.importCloudPages(
        session(1),
        car,
        Stream.value([
          {...row(0), 'owner_id': 'other'},
        ]),
        owner!,
      ),
      throwsStateError,
    );
    await expectLater(
      store.importCloudPages(
        session(1),
        car,
        Stream.value([
          {...row(0), 'value': null},
        ]),
        owner!,
      ),
      throwsStateError,
    );
    await expectLater(
      store.importCloudPages(
        session(1),
        car,
        Stream.value([row(0), row(0)]),
        owner!,
      ),
      throwsStateError,
    );
    expect(await store.listRecordings(owner), isEmpty);
  });
  test('active account runs back up full chunks; final tail uploads only after stopping', () async {
    final cloud = _ChunkCloud();
    addTearDown(cloud.client.dispose);
    final sync = RecordingSyncService(
      store: store,
      cloud: cloud,
      batchSize: 1000,
      automaticRetry: false,
    );
    addTearDown(sync.dispose);
    final id = await store.start(car, fixtureDevice);
    for (var i = 0; i < 2050; i++) {
      await store.append(id, fixtureSample(i));
    }
    await sync.upload(id);
    expect(cloud.batches.map((b) => b.length), [1000, 1000]);
    expect(cloud.completed, 0);
    expect((await store.recording(id)).uploadedSampleCount, 2000);
    await store.finish(id);
    await sync.upload(id);
    expect(cloud.batches.map((b) => b.length), [1000, 1000, 50]);
    expect(cloud.completed, 1);
    expect((await store.recording(id)).syncState, RecordingSyncState.synced);
    expect((await store.recording(id)).sampleCount, 2050);
  });
  test(
    'restart closes an interrupted durable recording without losing readings',
    () async {
      final id = await store.start(car, fixtureDevice);
      await store.append(id, fixtureSample(0));
      await store.recoverInterruptedRecordings();
      final run = await store.recording(id);
      expect(run.endedAt, isNotNull);
      expect(run.sampleCount, 1);
      expect(run.syncState, RecordingSyncState.pending);
      expect((await store.samples(id)).single.sample.value, 1000);
    },
  );
}
