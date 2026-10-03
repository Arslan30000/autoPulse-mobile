import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/account_service.dart';

import 'fixtures.dart';

const testOwner = '11111111-1111-4111-8111-111111111111';
Map<String, Object?> sessionResponse() {
  String segment(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final token =
      '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment({'sub': testOwner, 'exp': expires, 'role': 'authenticated'})}.test';
  return {
    'access_token': token,
    'refresh_token': 'synthetic-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': expires,
    'user': {
      'id': testOwner,
      'aud': 'authenticated',
      'email': 'fixture@example.test',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    },
  };
}

void main() {
  test('Supabase requests preserve individual samples and use duplicate-safe batch keys', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://fixture.supabase.co',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode(sessionResponse()),
            200,
            request: request,
          );
        }
        requests.add(request);
        return http.Response(
          request.url.path.endsWith('complete_obd_recording') ? 'null' : '',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic-password',
    );
    final repository = SupabaseRecordingRepository(client);
    final recording = ObdRecording(
      id: 1,
      vehicleName: 'Synthetic Fixture',
      startedAt: DateTime.utc(2026),
      endedAt: DateTime.utc(2026, 1, 1, 0, 1),
      sampleCount: 2,
      cloudId: '22222222-2222-4222-8222-222222222222',
      ownerId: testOwner,
      vehicle: fixtureVehicle.copyWith(
        id: '33333333-3333-4333-8333-333333333333',
      ),
      adapterName: 'Synthetic adapter',
    );
    await repository.prepare(recording, testOwner);
    await repository.upload(recording, testOwner, [
      RecordedObdSample(1, fixtureSample(0)),
      RecordedObdSample(
        2,
        fixtureSample(1, status: ObdSampleStatus.noData),
        storedUnit: 'original-unit',
      ),
    ]);
    await repository.complete(recording, testOwner);
    expect(requests.length, 4);
    final batch = requests[2];
    expect(batch.url.queryParameters['on_conflict'], 'session_id,sample_id');
    expect(
      batch.headers['Prefer'] ?? batch.headers['prefer'],
      contains('resolution=ignore-duplicates'),
    );
    final rows = jsonDecode(batch.body) as List;
    expect(rows[0]['owner_id'], testOwner);
    expect(rows[0]['value'], 1000);
    expect(rows[0]['requested_at'], '2026-01-01T00:00:00.000Z');
    expect(rows[1]['value'], isNull);
    expect(rows[1]['quality'], 'noData');
    expect(rows[1]['unit'], 'original-unit');
    expect(rows[1]['ecu_source'], '7E8');
    expect(jsonDecode(requests.last.body)['recording_id'], recording.cloudId);
    await expectLater(
      repository.upload(recording, 'other-owner', []),
      throwsStateError,
    );
    expect(requests.length, 4);
  });

  test(
    'registration with email confirmation does not pretend a session exists',
    () async {
      final user = sessionResponse()['user'];
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'synthetic-public-key',
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient(
          (request) async =>
              http.Response(jsonEncode(user), 200, request: request),
        ),
      );
      addTearDown(client.dispose);
      final account = AccountService()..configure(client);
      expect(
        await account.signUp('fixture@example.test', 'synthetic-password'),
        isFalse,
      );
      expect(account.userId, isNull);
    },
  );
}
