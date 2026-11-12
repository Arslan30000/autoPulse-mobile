import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_chunk_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'synthetic 32000-reading restore measures requests and bounded concurrency',
    () async {
      const owner = 'synthetic-owner';
      const session = 'synthetic-trip';
      const chunkCount = 32;
      const rowsPerChunk = 1000;
      final objects = <String, Uint8List>{};
      final manifests = <Map<String, dynamic>>[];
      for (var chunk = 0; chunk < chunkCount; chunk++) {
        final rows = List.generate(rowsPerChunk, (i) {
          final id = chunk * rowsPerChunk + i + 1;
          final time = DateTime.utc(2026)
              .add(Duration(milliseconds: id * 800))
              .toIso8601String();
          return <String, dynamic>{
            'session_id': session,
            'owner_id': owner,
            'sample_id': id,
            'pid': 12,
            'value': 800.0 + id % 2500,
            'unit': 'rpm',
            'quality': 'valid',
            'requested_at': time,
            'received_at': time,
            'latency_ms': 0,
            'ecu_source': '7E8',
          };
        });
        final bytes = RecordingChunkCodec.encode(rows);
        final name = 'chunk-$chunk.gz';
        objects[name] = bytes;
        manifests.add({
          'first_sample_id': chunk * rowsPerChunk + 1,
          'last_sample_id': (chunk + 1) * rowsPerChunk,
          'previous_sample_id': chunk * rowsPerChunk,
          'sample_count': rowsPerChunk,
          'byte_count': bytes.length,
          'sha256': RecordingChunkCodec.checksum(bytes),
          'object_path': '$owner/$session/$name',
        });
      }
      var manifestRequests = 0;
      var objectRequests = 0;
      var downloads = 0;
      var maximumDownloads = 0;
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'public',
        accessToken: () async => 'synthetic',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/obd_recording_chunks')) {
            manifestRequests++;
            await Future<void>.delayed(const Duration(milliseconds: 40));
            final cursor = int.parse(
              request.url.queryParameters['last_sample_id']!.substring(3),
            );
            final limit = int.parse(request.url.queryParameters['limit']!);
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
          objectRequests++;
          downloads++;
          maximumDownloads = math.max(maximumDownloads, downloads);
          await Future<void>.delayed(const Duration(milliseconds: 40));
          downloads--;
          return http.Response.bytes(
            objects[request.url.pathSegments.last]!,
            200,
            request: request,
          );
        }),
      );
      final store = SqliteObdRecordingRepository(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        owner: () => owner,
      );
      addTearDown(() async {
        await client.dispose();
        await store.close();
      });
      final cloud = SupabaseRecordingRepository(
        client,
        accountOwner: () => owner,
      );
      final run = <String, dynamic>{
        'id': session,
        'owner_id': owner,
        'vehicle_name': 'Synthetic Fixture',
        'adapter_name': 'Synthetic adapter',
        'started_at': '2026-01-01T00:00:00Z',
        'ended_at': '2026-01-01T10:00:00Z',
        'uploaded_at': '2026-01-01T10:01:00Z',
        'sample_count': chunkCount * rowsPerChunk,
        'storage_format': 'gzip-json-v1',
      };
      final watch = Stopwatch()..start();
      await store.importCloudPages(
        run,
        const Vehicle(
          id: 'car',
          ownerId: owner,
          make: 'Synthetic',
          model: 'Fixture',
          year: 2021,
        ),
        cloud.samplePages(run, owner),
        owner,
      );
      watch.stop();
      expect((await store.listRecordings(owner)).single.sampleCount, 32000);
      expect(objectRequests, chunkCount);
      expect(manifestRequests, 2);
      expect(maximumDownloads, inInclusiveRange(2, 3));
      // ignore: avoid_print
      print(
        jsonEncode({
          'syntheticRows': 32000,
          'latencyPerRequestMs': 40,
          'manifestRequests': manifestRequests,
          'objectRequests': objectRequests,
          'maxConcurrentDownloads': maximumDownloads,
          'elapsedMs': watch.elapsedMilliseconds,
        }),
      );
    },
  );
}
