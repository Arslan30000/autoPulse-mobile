import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_chunk_codec.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('compressed protocol retries an acknowledged-lost object and restores verified pages', () async {
    const owner = '11111111-1111-4111-8111-111111111111';
    const session = '22222222-2222-4222-8222-222222222222';
    String? currentOwner = owner;
    Uint8List? stored;
    Map<String, dynamic>? manifest;
    Map<String, dynamic>? reservation;
    var loseAcknowledgment = true;
    var finalized = false;
    var rowWrites = 0;
    final samples = [
      RecordedObdSample(10, fixtureSample(0)),
      RecordedObdSample(15, fixtureSample(1)),
    ];
    final expectedRows = samples
        .map((s) => SupabaseRecordingRepository.encodeSample(session, owner, s))
        .toList();
    final expectedBytes = RecordingChunkCodec.encode(expectedRows);
    final client = SupabaseClient(
      'https://fixture.supabase.co',
      'public',
      accessToken: () async => 'synthetic',
      httpClient: MockClient((request) async {
        http.Response json(Object? value, {int status = 200}) => http.Response(
          jsonEncode(value),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
        final path = request.url.path;
        if (path.endsWith('/obd_recording_samples')) {
          rowWrites++;
          return json(null);
        }
        if (path.endsWith('/obd_recording_sessions')) {
          return json(request.method == 'GET' ? [] : null);
        }
        if (path.endsWith('/vehicles')) return json(null);
        if (path.endsWith('/reserve_recording_chunk')) {
          final args = jsonDecode(request.body) as Map<String, dynamic>;
          if (reservation != null) expect(args, reservation);
          reservation = args;
          expect(args['previous_id'], 0);
          expect(args['compressed_bytes'], expectedBytes.length);
          expect(
            args['digest_sha256'],
            RecordingChunkCodec.checksum(expectedBytes),
          );
          final objectPath =
              '$owner/$session/10-${args['digest_sha256']}.json.gz';
          manifest = {
            'first_sample_id': 10,
            'last_sample_id': 15,
            'previous_sample_id': 0,
            'sample_count': 2,
            'byte_count': expectedBytes.length,
            'sha256': args['digest_sha256'],
            'object_path': objectPath,
          };
          return json(objectPath);
        }
        if (path.endsWith('/obd_recording_chunks')) {
          if (request.url.queryParameters.containsKey('first_sample_id')) {
            return json([]);
          }
          final cursor = request.url.queryParameters['last_sample_id'];
          return json(cursor == 'gt.0' && manifest != null ? [manifest] : []);
        }
        if (path.contains('/storage/v1/object/')) {
          if (request.method == 'GET') {
            return http.Response.bytes(stored!, 200, request: request);
          }
          expect(request.headers['x-upsert'], 'false');
          if (stored != null) {
            return json({
              'statusCode': '409',
              'error': 'Duplicate',
              'message': 'Already exists',
            }, status: 409);
          }
          // The SDK uploads multipart data. Check that the exact gzip archive
          // is present, rather than treating the multipart envelope as the file.
          final body = request.bodyBytes;
          final start = List.generate(body.length - 2, (i) => i).firstWhere(
            (i) => body[i] == 31 && body[i + 1] == 139 && body[i + 2] == 8,
          );
          stored = Uint8List.fromList(
            body.sublist(start, start + expectedBytes.length),
          );
          expect(stored, expectedBytes);
          if (loseAcknowledgment) {
            loseAcknowledgment = false;
            return json({
              'statusCode': '503',
              'error': 'ServiceUnavailable',
              'message': 'Synthetic lost acknowledgment',
            }, status: 503);
          }
          return json({'Key': manifest!['object_path']});
        }
        if (path.endsWith('/complete_obd_recording')) {
          finalized = true;
          return json(null);
        }
        throw StateError('Unexpected protocol request: $path');
      }),
    );
    addTearDown(client.dispose);
    final cloud = SupabaseRecordingRepository(
      client,
      compressed: true,
      accountOwner: () => currentOwner,
    );
    final run = ObdRecording(
      id: 1,
      vehicleName: 'Fixture',
      startedAt: DateTime.utc(2026),
      endedAt: DateTime.utc(2026, 1, 1, 0, 1),
      sampleCount: 2,
      cloudId: session,
      ownerId: owner,
      vehicle: fixtureVehicle.copyWith(
        id: '33333333-3333-4333-8333-333333333333',
        ownerId: owner,
      ),
    );
    await cloud.prepare(run, owner);
    await expectLater(
      cloud.upload(run, owner, samples),
      throwsA(isA<StorageException>()),
    );
    await cloud.upload(run, owner, samples);
    await cloud.complete(run, owner);
    expect(finalized, isTrue);
    expect(
      rowWrites,
      0,
      reason: 'New archives must not duplicate readings as SQL rows.',
    );
    final pages = await cloud.samplePages({
      'id': session,
      'storage_format': 'gzip-json-v1',
    }, owner).toList();
    expect(pages, [expectedRows]);
    stored = Uint8List.fromList(stored!)..[0] = 0;
    await expectLater(
      cloud.samplePages({
        'id': session,
        'storage_format': 'gzip-json-v1',
      }, owner).toList(),
      throwsFormatException,
    );
    currentOwner = 'other-owner';
    await expectLater(cloud.upload(run, owner, samples), throwsStateError);
  });
}
