import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_chunk_codec.dart';
import 'package:autopulse_ai/services/recording_restore_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Fixture {
  static const account = 'synthetic-owner';
  static const car = Vehicle(
    id: 'car',
    ownerId: account,
    make: 'Synthetic',
    model: 'Fixture',
    year: 2021,
  );
  String? owner = account;
  final int chunkCount;
  final int manifestCap;
  final manifests = <Map<String, dynamic>>[];
  final objects = <Uint8List>[];
  final requests = <int>[];
  final completed = <int>[];
  final cursors = <int>[];
  int? failIndex;
  int? corruptIndex;
  bool changeOwner = false;
  int active = 0;
  int maximumActive = 0;
  late final SupabaseClient client;
  late final SqliteObdRecordingRepository store;
  late final RecordingRestoreService restorer;
  _Fixture(this.chunkCount, {this.manifestCap = 64}) {
    for (var chunk = 0; chunk < chunkCount; chunk++) {
      final bytes = RecordingChunkCodec.encode([
        for (var i = 1; i <= 3; i++)
          {
            'session_id': 'trip',
            'owner_id': account,
            'sample_id': chunk * 3 + i,
            'pid': 12,
            'value': 800.0 + chunk * 3 + i,
            'unit': 'rpm',
            'quality': 'valid',
            'requested_at': '2026-01-01T00:00:00Z',
            'received_at': '2026-01-01T00:00:00Z',
            'latency_ms': 0,
            'ecu_source': '7E8',
          },
      ]);
      objects.add(bytes);
      manifests.add({
        'first_sample_id': chunk * 3 + 1,
        'last_sample_id': (chunk + 1) * 3,
        'previous_sample_id': chunk * 3,
        'sample_count': 3,
        'byte_count': bytes.length,
        'sha256': RecordingChunkCodec.checksum(bytes),
        'object_path': '$account/trip/$chunk.gz',
      });
    }
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'public',
      accessToken: () async => 'synthetic',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/obd_recording_chunks')) {
          final cursor = int.parse(
            request.url.queryParameters['last_sample_id']!.substring(3),
          );
          cursors.add(cursor);
          final limit = math.min(
            manifestCap,
            int.parse(request.url.queryParameters['limit']!),
          );
          return http.Response(
            jsonEncode(
              manifests
                  .where((m) => (m['last_sample_id'] as int) > cursor)
                  .take(limit)
                  .toList(),
            ),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        final index = int.parse(request.url.pathSegments.last.split('.').first);
        requests.add(index);
        active++;
        maximumActive = math.max(maximumActive, active);
        try {
          // The first object arrives last: publication must still stay ordered.
          await Future<void>.delayed(
            Duration(milliseconds: index == 0 ? 20 : 5),
          );
          if (changeOwner) owner = 'other-owner';
          if (failIndex == index) throw StateError('Synthetic download outage');
          completed.add(index);
          final bytes = Uint8List.fromList(objects[index]);
          if (corruptIndex == index) bytes[0] = 0;
          return http.Response.bytes(bytes, 200, request: request);
        } finally {
          active--;
        }
      }),
    );
    store = SqliteObdRecordingRepository(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      owner: () => owner,
    );
    restorer = RecordingRestoreService(
      store: store,
      cloud: SupabaseRecordingRepository(client, accountOwner: () => owner),
    );
    addTearDown(() async {
      // Allow the bounded prefetch window to settle, including handled errors.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await store.close();
      await client.dispose();
    });
  }
  Map<String, dynamic> get run => {
    'id': 'trip',
    'owner_id': account,
    'vehicle_name': 'Synthetic Fixture',
    'adapter_name': 'Synthetic adapter',
    'started_at': '2026-01-01T00:00:00Z',
    'ended_at': '2026-01-01T10:00:00Z',
    'uploaded_at': '2026-01-01T10:01:00Z',
    'sample_count': chunkCount * 3,
    'storage_format': 'gzip-json-v1',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'legacy row restores tolerate a server cap below the requested page size',
    () async {
      final fixture = _Fixture(2);
      final rows = [
        for (final bytes in fixture.objects)
          ...RecordingChunkCodec.decode(
            bytes,
            expectedChecksum: RecordingChunkCodec.checksum(bytes),
            expectedRows: 3,
          ),
      ];
      final cursors = <int>[];
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'public',
        accessToken: () async => 'synthetic',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['limit'], '1000');
          final cursor = int.parse(
            request.url.queryParameters['sample_id']!.substring(3),
          );
          cursors.add(cursor);
          return http.Response(
            jsonEncode(
              rows
                  .where((row) => (row['sample_id'] as int) > cursor)
                  .take(2)
                  .toList(),
            ),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final restorer = RecordingRestoreService(
        store: fixture.store,
        cloud: SupabaseRecordingRepository(
          client,
          accountOwner: () => fixture.owner,
        ),
      );
      await restorer.restore(
        {...fixture.run, 'storage_format': 'rows-v1'},
        _Fixture.car,
        _Fixture.account,
      );
      expect(cursors, [0, 2, 4, 6]);
      expect(
        (await fixture.store.listRecordings(_Fixture.account))
            .single
            .sampleCount,
        6,
      );
    },
  );

  test(
    'an inconsistent staged prefix is repaired once instead of remaining stuck',
    () async {
      final fixture = _Fixture(3);
      final first = RecordingChunkCodec.decode(
        fixture.objects.first,
        expectedChecksum: RecordingChunkCodec.checksum(fixture.objects.first),
        expectedRows: 3,
      );
      await expectLater(
        fixture.store.importCloudPages(
          fixture.run,
          _Fixture.car,
          Stream.value([first[0], first[2]]),
          _Fixture.account,
        ),
        throwsStateError,
      );
      final progress = <int>[];
      await fixture.restorer.restore(
        fixture.run,
        _Fixture.car,
        _Fixture.account,
        onProgress: (done, _) => progress.add(done),
      );
      expect(progress.first, 2);
      expect(progress, contains(0));
      expect(fixture.cursors, [3, 9, 0, 9]);
      expect(
        (await fixture.store.listRecordings(_Fixture.account))
            .single
            .sampleCount,
        9,
      );
    },
  );

  test('cancelling after one page handles unused prefetch failures', () async {
    final fixture = _Fixture(8)..failIndex = 2;
    final pages = await fixture.restorer.cloud
        .samplePages(fixture.run, _Fixture.account)
        .take(1)
        .toList();
    expect(pages.single, hasLength(3));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(fixture.requests.length, lessThanOrEqualTo(4));
    expect(fixture.maximumActive, lessThanOrEqualTo(3));
  });

  test(
    'parallel objects restore in acquisition order with bounded concurrency',
    () async {
      final fixture = _Fixture(8);
      await fixture.restorer.restore(
        fixture.run,
        _Fixture.car,
        _Fixture.account,
      );
      final run = (await fixture.store.listRecordings(_Fixture.account)).single;
      final samples = await fixture.store.samples(run.id);
      expect(samples.map((s) => s.sample.value), [
        for (var i = 1; i <= 24; i++) 800.0 + i,
      ]);
      expect(fixture.maximumActive, inInclusiveRange(2, 3));
      expect(
        fixture.completed.indexOf(1),
        lessThan(fixture.completed.indexOf(0)),
      );
      expect(fixture.cursors, [0, 24]);
    },
  );
  test(
    'interrupted restore downloads only the unfinished suffix on retry',
    () async {
      final fixture = _Fixture(5)..failIndex = 2;
      await expectLater(
        fixture.restorer.restore(fixture.run, _Fixture.car, _Fixture.account),
        throwsStateError,
      );
      expect(await fixture.store.listRecordings(_Fixture.account), isEmpty);
      expect(
        await fixture.store.restoreCursor(fixture.run, _Fixture.account),
        6,
      );
      // Let prefetched requests from the failed attempt finish before retrying.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final beforeRetry = fixture.requests.length;
      fixture.failIndex = null;
      final progress = <int>[];
      await fixture.restorer.restore(
        fixture.run,
        _Fixture.car,
        _Fixture.account,
        onProgress: (done, total) {
          progress.add(done);
          expect(total, 15);
        },
      );
      expect(fixture.requests.skip(beforeRetry), [2, 3, 4]);
      expect(fixture.cursors, contains(6));
      expect(progress, [6, 9, 12, 15]);
      expect(
        (await fixture.store.listRecordings(_Fixture.account))
            .single
            .sampleCount,
        15,
      );
    },
  );
  test('server-capped manifest pages do not truncate a restore', () async {
    final fixture = _Fixture(5, manifestCap: 2);
    await fixture.restorer.restore(fixture.run, _Fixture.car, _Fixture.account);
    expect(fixture.cursors, [0, 6, 12, 15]);
    expect(
      (await fixture.store.listRecordings(_Fixture.account)).single.sampleCount,
      15,
    );
  });
  test(
    'prefetch retains checksum validation and never publishes partial trips',
    () async {
      final fixture = _Fixture(5)..corruptIndex = 1;
      await expectLater(
        fixture.restorer.restore(fixture.run, _Fixture.car, _Fixture.account),
        throwsFormatException,
      );
      expect(await fixture.store.listRecordings(_Fixture.account), isEmpty);
      expect(
        await fixture.store.restoreCursor(fixture.run, _Fixture.account),
        3,
      );
    },
  );
  test('an account change stops prefetched data before publication', () async {
    final fixture = _Fixture(5)..changeOwner = true;
    await expectLater(
      fixture.restorer.restore(fixture.run, _Fixture.car, _Fixture.account),
      throwsStateError,
    );
    expect(await fixture.store.listRecordings('other-owner'), isEmpty);
  });
}
