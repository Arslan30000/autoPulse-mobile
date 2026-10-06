import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';

import 'fixtures.dart';

class FakeCloud implements CloudRecordingRepository {
  @override
  String? ownerId = 'owner-a';
  final Map<String, RecordedObdSample> rows = {};
  final List<List<int>> batches = [];
  bool loseAcknowledgment = false;
  bool failComplete = false;
  Completer<void>? gate;
  int completions = 0;
  @override
  Future<void> prepare(ObdRecording recording, String owner) async {}
  @override
  Future<void> upload(
    ObdRecording recording,
    String owner,
    List<RecordedObdSample> samples,
  ) async {
    await gate?.future;
    batches.add(samples.map((s) => s.id).toList());
    for (final sample in samples) {
      rows.putIfAbsent('${recording.cloudId}:${sample.id}', () => sample);
    }
    if (loseAcknowledgment) {
      loseAcknowledgment = false;
      throw TimeoutException('Synthetic lost acknowledgment');
    }
  }

  @override
  Future<void> complete(ObdRecording recording, String owner) async {
    if (failComplete) throw TimeoutException('Synthetic finalization failure');
    if (rows.keys.where((k) => k.startsWith('${recording.cloudId}:')).length !=
        recording.sampleCount) {
      throw StateError('Incomplete recording');
    }
    completions++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late SqliteObdRecordingRepository store;
  late FakeCloud cloud;
  late RecordingSyncService sync;
  late int id;
  setUp(() async {
    store = SqliteObdRecordingRepository(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      owner: () => null,
    );
    cloud = FakeCloud();
    sync = RecordingSyncService(
      store: store,
      cloud: cloud,
      batchSize: 2,
      automaticRetry: false,
    );
    id = await store.start(fixtureVehicle, fixtureDevice);
    for (var i = 0; i < 5; i++) {
      await store.append(id, fixtureSample(i));
    }
    await store.finish(id);
  });
  tearDown(() async {
    sync.dispose();
    await store.close();
  });

  test(
    'lost batch acknowledgment retries without duplicating any cloud sample',
    () async {
      cloud.loseAcknowledgment = true;
      await expectLater(sync.upload(id), throwsA(isA<TimeoutException>()));
      final failed = await store.recording(id);
      expect(failed.syncState, RecordingSyncState.failed);
      expect(failed.uploadedSampleId, 0);
      expect(cloud.rows.length, 2);
      // A new worker models app restart; SQLite remains the upload source of truth.
      sync.dispose();
      sync = RecordingSyncService(
        store: store,
        cloud: cloud,
        batchSize: 2,
        automaticRetry: false,
      );
      await sync.retryPending();
      expect(cloud.rows.length, 5);
      expect(cloud.batches.map((b) => b.length), [2, 2, 2, 1]);
      expect((await store.recording(id)).syncState, RecordingSyncState.synced);
      expect(cloud.completions, 1);
    },
  );

  test('finalization retry does not retransmit acknowledged batches', () async {
    cloud.failComplete = true;
    await expectLater(sync.upload(id), throwsA(isA<TimeoutException>()));
    expect((await store.recording(id)).uploadedSampleId, 5);
    expect(cloud.batches.length, 3);
    cloud.failComplete = false;
    await sync.upload(id);
    expect(cloud.batches.length, 3);
    expect((await store.recording(id)).syncState, RecordingSyncState.synced);
  });

  test('account change pauses before saving an acknowledgment or sending more data', () async {
    cloud.gate = Completer<void>();
    final pending = sync.upload(id);
    final error = expectLater(pending, throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    cloud.ownerId = 'owner-b';
    cloud.gate!.complete();
    await error;
    expect(cloud.batches.length, 1);
    expect((await store.recording(id)).uploadedSampleId, 0);
    await expectLater(sync.upload(id), throwsStateError);
    expect(cloud.batches.length, 1);
  });

  test('concurrent upload calls use one worker', () async {
    cloud.gate = Completer<void>();
    final pending = sync.upload(id);
    await sync.upload(id);
    cloud.gate!.complete();
    await pending;
    expect(cloud.batches.length, 3);
    expect(cloud.rows.length, 5);
  });

  test('unrequested local sessions are never uploaded automatically', () async {
    await sync.retryPending();
    expect(cloud.rows, isEmpty);
    expect((await store.recording(id)).ownerId, isNull);
  });

  test('signed-out users cannot claim or upload sessions', () async {
    cloud.ownerId = null;
    await expectLater(sync.upload(id), throwsStateError);
    expect((await store.recording(id)).ownerId, isNull);
    expect(cloud.rows, isEmpty);
  });

  test(
    'progress resumes from counted samples rather than global SQLite IDs',
    () async {
      final other = await store.start(fixtureVehicle, fixtureDevice);
      for (var i = 0; i < 7; i++) {
        await store.append(other, fixtureSample(i));
      }
      await store.finish(other);
      final target = await store.start(fixtureVehicle, fixtureDevice);
      for (var i = 0; i < 3; i++) {
        await store.append(target, fixtureSample(i));
        await store.append(
          await store.start(fixtureVehicle, fixtureDevice),
          fixtureSample(i),
        );
      }
      await store.finish(target);
      final recording = await store.claimCompleted(target, 'owner-a');
      final acknowledged = await store.samples(target, limit: 1);
      await cloud.prepare(recording, 'owner-a');
      await cloud.upload(recording, 'owner-a', acknowledged);
      await store.checkpoint(target, 'owner-a', acknowledged.single.id);
      expect(acknowledged.single.id, greaterThan(1));
      expect((await store.recording(target)).uploadedSampleCount, 1);
      final counts = <int>[];
      sync.addListener(() {
        if (sync.totalSamples > 0) counts.add(sync.uploadedSamples);
      });
      await sync.upload(target);
      expect(counts, contains(1));
      expect(sync.uploadedSamples, 3);
      expect(sync.totalSamples, 3);
      expect(sync.progress, 1);
      expect((await store.recording(target)).uploadedSampleCount, 3);
      expect(sync.message, 'Trip uploaded to Supabase.');
      await sync.upload(target);
      expect(sync.message, 'Trip already uploaded to Supabase.');
      expect(cloud.completions, 1);
    },
  );
}
