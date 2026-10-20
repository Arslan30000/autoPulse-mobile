// Opt-in: flutter test test/live_backend_audit_test.dart
//   --dart-define=LIVE_BACKEND_AUDIT=true
// Creates/reuses two synthetic accounts and leaves labelled synthetic data in
// those accounts. Credentials stay in the ignored .dart_tool directory.
import 'dart:convert';
import 'dart:io';

import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'live signup, login, profile, upload, duplicate retry, restore and account isolation',
    () async {
      // This opt-in integration audit intentionally uses real HTTP. The default
      // widget-test binding otherwise replaces every request with a synthetic 400.
      HttpOverrides.global = null;
      final config = jsonDecode(
        await File('assets/supabase.public.json').readAsString(),
      ) as Map<String, dynamic>;
      final env = <String, String>{};
      if (await File('.env').exists()) {
        for (final line in await File('.env').readAsLines()) {
          final separator = line.indexOf('=');
          if (separator > 0 && !line.trimLeft().startsWith('#')) {
            env[line.substring(0, separator).trim()] = line
                .substring(separator + 1)
                .trim()
                .replaceAll(RegExp(r'''^['"]|['"]$'''), '');
          }
        }
      }
      final url = env['SUPABASE_URL'] ?? config['url'] as String;
      final key =
          env['SUPABASE_PUBLISHABLE_KEY'] ??
          env['SUPABASE_ANON_KEY'] ??
          config['publicKey'] as String;
      final settings = await http
          .get(Uri.parse('$url/auth/v1/settings'), headers: {'apikey': key})
          .timeout(const Duration(seconds: 20));
      expect(settings.statusCode, 200);
      final options = jsonDecode(settings.body) as Map<String, dynamic>;
      expect(
        options['mailer_autoconfirm'],
        isTrue,
        reason: 'This audit must never send confirmation emails. Use precreated test accounts if confirmation is enabled.',
      );
      expect(options['disable_signup'], isFalse);

      final credentialsFile = File('.dart_tool/live-demo-audit-accounts.json');
      final List<dynamic> credentials;
      if (await credentialsFile.exists()) {
        credentials = jsonDecode(await credentialsFile.readAsString()) as List;
      } else {
        credentials = [
          for (var i = 0; i < 2; i++)
            {
              'email': 'autopulse-demo-audit-${const Uuid().v4()}@example.com',
              'password': '${const Uuid().v4()}Aa!9',
              'created': false,
            },
        ];
        await credentialsFile.writeAsString(
          jsonEncode(credentials),
          flush: true,
        );
      }
      final clients = [
        for (var i = 0; i < 2; i++)
          SupabaseClient(
            url,
            key,
            authOptions: const AuthClientOptions(
              autoRefreshToken: false,
              authFlowType: AuthFlowType.implicit,
            ),
          ),
      ];
      SqliteObdRecordingRepository? store;
      RecordingSyncService? sync;
      try {
        for (var i = 0; i < clients.length; i++) {
          final credential = credentials[i] as Map<String, dynamic>;
          if (credential['created'] != true) {
            final registered = await clients[i].auth
                .signUp(
                  email: credential['email'] as String,
                  password: credential['password'] as String,
                  data: {'display_name': 'Synthetic demo audit ${i + 1}'},
                )
                .timeout(const Duration(seconds: 20));
            expect(registered.session, isNotNull);
            credential['created'] = true;
            await credentialsFile.writeAsString(
              jsonEncode(credentials),
              flush: true,
            );
            await clients[i].auth.signOut(scope: SignOutScope.local);
          }
          final signedIn = await clients[i].auth
              .signInWithPassword(
                email: credential['email'] as String,
                password: credential['password'] as String,
              )
              .timeout(const Duration(seconds: 20));
          expect(signedIn.session, isNotNull);
        }
        final owner = clients[0].auth.currentUser!.id;
        final other = clients[1];
        final account = AccountService.instance..configure(clients[0]);
        await account.updateName('Synthetic demo audit owner');
        final profile = await clients[0]
            .from('profiles')
            .select()
            .eq('id', owner)
            .single();
        expect(profile['display_name'], 'Synthetic demo audit owner');
        expect(await other.from('profiles').select().eq('id', owner), isEmpty);

        sqfliteFfiInit();
        store = SqliteObdRecordingRepository(
          factory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
          owner: () => owner,
        );
        final car = Vehicle(
          id: const Uuid().v4(),
          ownerId: owner,
          make: 'Synthetic',
          model: 'Demo audit fixture',
          year: 2020,
        );
        final id = await store.start(
          car,
          const ObdDevice(
            name: 'Synthetic audit adapter',
            address: 'test-only',
          ),
        );
        for (final reading in [
          (ObdParameter.rpm, 1726.0),
          (ObdParameter.speed, 0.0),
          (ObdParameter.coolant, null),
        ]) {
          final time = DateTime.now().toUtc();
          await store.append(
            id,
            ObdSample(
              parameter: reading.$1,
              value: reading.$2,
              status: reading.$2 == null
                  ? ObdSampleStatus.noData
                  : ObdSampleStatus.valid,
              requestedAt: time,
              receivedAt: time.add(const Duration(milliseconds: 100)),
              latencyMs: 100,
              source: '7E8',
            ),
          );
        }
        await store.finish(id);
        final cloud = SupabaseRecordingRepository(clients[0]);
        sync = RecordingSyncService(
          store: store,
          cloud: cloud,
          automaticRetry: false,
          batchSize: 2,
        );
        await sync.upload(id);
        final recording = await store.recording(id);
        expect(recording.syncState, RecordingSyncState.synced);
        expect(recording.uploadedSampleCount, 3);
        final samples = await store.samples(id);
        // Replay the exact acknowledged payload as if an upload acknowledgment was lost.
        await cloud.upload(recording, owner, samples);
        final run = await clients[0]
            .from('obd_recording_sessions')
            .select()
            .eq('id', recording.cloudId)
            .single();
        final rows = await cloud.downloadSamples(
          recording.cloudId,
          owner,
          pageSize: 2,
        );
        expect(rows, hasLength(3));
        expect(rows.map((row) => row['value']), [1726, 0, null]);
        expect(rows.last['quality'], 'noData');
        expect(run['uploaded_at'], isNotNull);
        expect(
          await other.from('vehicles').select().eq('id', car.id!),
          isEmpty,
        );
        expect(
          await other
              .from('obd_recording_sessions')
              .select()
              .eq('id', recording.cloudId),
          isEmpty,
        );
        expect(
          await other
              .from('obd_recording_samples')
              .select()
              .eq('session_id', recording.cloudId),
          isEmpty,
        );
        await expectLater(
          other.from('vehicles').insert({
            'id': const Uuid().v4(),
            'owner_id': owner,
            'make': 'Synthetic',
            'model': 'Forbidden audit insert',
            'year': 2020,
          }),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          other.rpc(
            'complete_obd_recording',
            params: {'recording_id': recording.cloudId},
          ),
          throwsA(isA<PostgrestException>()),
        );

        await account.signOut();
        expect(account.userId, isNull);
        await expectLater(cloud.prepare(recording, owner), throwsStateError);
        await account.signIn(
          credentials[0]['email'] as String,
          credentials[0]['password'] as String,
        );
        expect(account.userId, owner);
        await store.close();
        store = SqliteObdRecordingRepository(
          factory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
          owner: () => owner,
        );
        await store.importCloud(run, car, rows, owner);
        final restored = (await store.listRecordings(owner)).single;
        expect(restored.sampleCount, 3);
        expect(restored.syncState, RecordingSyncState.synced);
        expect(
          (await store.samples(restored.id)).map((row) => row.sample.value),
          [1726, 0, null],
        );
        await File('.dart_tool/live-backend-result.json').writeAsString(
          jsonEncode({
            'passed': true,
            'at_utc': DateTime.now().toUtc().toIso8601String(),
            'synthetic_accounts': 2,
            'samples_uploaded_and_restored': 3,
            'tested': [
              'signup',
              'password login',
              'profile trigger',
              'upload completion RPC',
              'duplicate replay',
              'cross-account read and write isolation',
              'signout',
              'relogin',
              'SQLite restoration',
            ],
          }),
          flush: true,
        );
      } finally {
        AccountService.instance.configure(null);
        sync?.dispose();
        await store?.close();
        for (final client in clients) {
          await client.dispose();
        }
      }
    },
    skip: !const bool.fromEnvironment('LIVE_BACKEND_AUDIT'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
