import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_chunk_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('105120 synthetic readings compress and restore in bounded pages without loss', () async {
    const count = 105120;
    const owner = 'synthetic-owner';
    const car = Vehicle(
      id: 'car',
      ownerId: owner,
      make: 'Synthetic',
      model: 'Fixture',
      year: 2021,
    );
    final store = SqliteObdRecordingRepository(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      owner: () => owner,
    );
    addTearDown(store.close);
    var compressedBytes = 0;
    var maximumPage = 0;
    Stream<List<Map<String, dynamic>>> pages() async* {
      for (var offset = 0; offset < count; offset += 1000) {
        final rows = <Map<String, dynamic>>[];
        for (var i = offset; i < min(count, offset + 1000); i++) {
          final t = DateTime.utc(2026).add(Duration(milliseconds: 342 * i));
          final missing = i % 17 == 0;
          rows.add({
            'session_id': 'synthetic-trip',
            'sample_id': i + 1,
            'owner_id': owner,
            'pid': 12,
            'value': missing ? null : 800.0 + i % 2500,
            'unit': 'rpm',
            'quality': missing ? 'noData' : 'valid',
            'requested_at': t.toIso8601String(),
            'received_at': t
                .add(const Duration(milliseconds: 100))
                .toIso8601String(),
            'latency_ms': 100,
            'ecu_source': '7E8',
          });
        }
        final bytes = await RecordingChunkCodec.encodeAsync(rows);
        compressedBytes += bytes.length;
        final decoded = await RecordingChunkCodec.decodeAsync(
          bytes,
          expectedChecksum: RecordingChunkCodec.checksum(bytes),
          expectedRows: rows.length,
        );
        expect(decoded, rows);
        maximumPage = max(maximumPage, decoded.length);
        yield decoded;
      }
    }

    await store.importCloudPages(
      {
        'id': 'synthetic-trip',
        'owner_id': owner,
        'vehicle_name': 'Synthetic Fixture',
        'adapter_name': 'Synthetic adapter',
        'started_at': '2026-01-01T00:00:00Z',
        'ended_at': '2026-01-01T10:00:00Z',
        'uploaded_at': '2026-01-01T10:01:00Z',
        'sample_count': count,
      },
      car,
      pages(),
      owner,
    );
    final run = (await store.listRecordings(owner)).single;
    expect(run.sampleCount, count);
    expect(maximumPage, 1000);
    var read = 0;
    var cursor = 0;
    while (true) {
      final rows = await store.samples(run.id, afterId: cursor, limit: 1000);
      if (rows.isEmpty) break;
      read += rows.length;
      cursor = rows.last.id;
    }
    expect(read, count);
    expect(compressedBytes, lessThan(20 * 1000000));
    // Synthetic transfer size only; this is not measured Yaris telemetry.
    // ignore: avoid_print
    print(
      'Synthetic 105120-reading archive: $compressedBytes compressed bytes, maximum $maximumPage readings per page.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
