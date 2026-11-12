import 'dart:async';
import 'dart:convert';

import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/services/account_data_service.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'recordings/supabase_recording_repository_test.dart'
    show sessionResponse, testOwner;

const _car = Vehicle(
  id: '33333333-3333-4333-8333-333333333333',
  ownerId: testOwner,
  make: 'Toyota',
  model: 'Yaris',
  year: 2020,
);

// Model Android's recording sync without a physical phone or live backend.
class _PausedRunSync extends AccountDataService {
  final runs = Completer<void>();
  final calls = <bool>[];

  @override
  bool get canStoreRuns => true;

  @override
  Future<void> synchronize({bool carsOnly = false}) async {
    calls.add(carsOnly);
    if (carsOnly) {
      await vehicles.mergeCloud([_car], testOwner);
      resolvedOwner = testOwner;
    } else {
      await runs.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(
      'https://fixture.supabase.co',
      'public',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(sessionResponse()),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    AccountService.instance.configure(client);
    addTearDown(() async {
      AccountService.instance.configure(null);
      await client.dispose();
    });
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic-password',
    );
  });

  for (final cached in [true, false]) {
    test(
      '${cached ? 'cached' : 'cloud-restored'} car opens while Android run sync is pending',
      () async {
        final service = _PausedRunSync();
        addTearDown(() {
          service.runs.complete();
          service.dispose();
        });
        if (cached) await service.vehicles.select(_car, testOwner);

        final vehicle = await service.restoreSelection().timeout(
          const Duration(seconds: 1),
        );

        expect(vehicle?.id, _car.id);
        expect(service.runs.isCompleted, isFalse);
        expect(service.calls, cached ? [false] : [true, false]);
      },
    );
  }
}
