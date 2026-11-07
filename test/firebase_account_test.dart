import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/services/account_service.dart';

import 'recordings/supabase_recording_repository_test.dart'
    show sessionResponse, testOwner;

class _User extends Fake implements firebase.User {
  @override
  String get uid => 'firebase-fixture';
  @override
  String get email => 'fixture@example.test';
  @override
  bool emailVerified = false;
  bool verifyOnReload = false;
  @override
  String? displayName;
  int verificationEmails = 0;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'synthetic-jwt';
  @override
  Future<void> sendEmailVerification([
    firebase.ActionCodeSettings? settings,
  ]) async {
    verificationEmails++;
  }

  @override
  Future<void> reload() async {
    if (verifyOnReload) emailVerified = true;
  }

  @override
  Future<void> updateDisplayName(String? name) async {
    displayName = name;
  }
}

class _Credential extends Fake implements firebase.UserCredential {
  @override
  final firebase.User user;
  _Credential(this.user);
}

class _Auth extends Fake implements firebase.FirebaseAuth {
  final user = _User();
  final events = StreamController<firebase.User?>.broadcast();
  @override
  firebase.User? currentUser;
  int resets = 0;
  @override
  Stream<firebase.User?> idTokenChanges() => events.stream;
  @override
  Future<firebase.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    currentUser = user;
    return _Credential(user);
  }

  @override
  Future<firebase.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    currentUser = user;
    return _Credential(user);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    firebase.ActionCodeSettings? actionCodeSettings,
  }) async {
    resets++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'startup refreshes verified identity and recovers its existing owner',
    () async {
      final auth = _Auth();
      auth.currentUser = auth.user;
      auth.user.verifyOnReload = true;
      final account = AccountService();
      var resolutions = 0;
      final cloud = SupabaseClient(
        'https://fixture.supabase.co',
        'public',
        accessToken: () async => 'synthetic',
        httpClient: MockClient((request) async {
          resolutions++;
          return http.Response(
            jsonEncode(testOwner),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final legacy = SupabaseClient('https://fixture.supabase.co', 'public');
      addTearDown(() async {
        account.configure(null);
        await auth.events.close();
        await cloud.dispose();
        await legacy.dispose();
      });
      await account.configureFirebase(auth, cloud, legacy);
      expect(account.userId, isNull);
      await account.restoreVerifiedSession();
      expect(account.userId, testOwner);
      expect(resolutions, 1);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'account.firebase.firebase-fixture',
        ),
        testOwner,
      );
    },
  );
  test('signup sends verification and never exposes cloud ownership before verification', () async {
    final auth = _Auth();
    final account = AccountService();
    var calls = 0;
    final cloud = SupabaseClient(
      'https://fixture.supabase.co',
      'public',
      accessToken: () async => 'synthetic',
      httpClient: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode(testOwner),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final legacy = SupabaseClient('https://fixture.supabase.co', 'public');
    addTearDown(() async {
      account.configure(null);
      await auth.events.close();
      await cloud.dispose();
      await legacy.dispose();
    });
    await account.configureFirebase(auth, cloud, legacy);
    expect(
      await account.signUp(
        'fixture@example.test',
        'synthetic-password',
        displayName: 'Owner',
      ),
      isFalse,
    );
    expect(auth.user.verificationEmails, 1);
    expect(account.needsVerification, isTrue);
    expect(account.userId, isNull);
    await expectLater(
      account.refreshVerification(),
      throwsA(isA<AuthException>()),
    );
    expect(calls, 0);
    await account.resendVerification();
    expect(auth.user.verificationEmails, 2);
    auth.user.emailVerified = true;
    await account.refreshVerification();
    expect(account.userId, testOwner);
    expect(calls, 1);
    await account.sendPasswordReset('fixture@example.test');
    expect(auth.resets, 1);
    final cached = AccountService();
    await cached.configureFirebase(auth, cloud, legacy);
    expect(cached.userId, testOwner);
    expect(
      calls,
      1,
      reason: 'Opening a verified local cache must work offline.',
    );
    cached.configure(null);
    await account.signOut();
    expect(account.userId, isNull);
  });
  test('legacy linking requires old-password authentication and preserves its original UUID', () async {
    final auth = _Auth();
    auth.user.emailVerified = true;
    final account = AccountService();
    final legacyPaths = <String>[];
    var linked = false;
    final cloud = SupabaseClient(
      'https://fixture.supabase.co',
      'public',
      accessToken: () async => 'synthetic',
      httpClient: MockClient((request) async {
        final args = jsonDecode(request.body) as Map? ?? {};
        if (args['link_ticket'] == '33333333-3333-4333-8333-333333333333') {
          linked = true;
        }
        return http.Response(
          linked
              ? jsonEncode(testOwner)
              : jsonEncode({
                  'message': 'LEGACY_LINK_REQUIRED',
                  'code': 'P0001',
                }),
          linked ? 200 : 400,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final legacy = SupabaseClient(
      'https://fixture.supabase.co',
      'public',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        legacyPaths.add(request.url.path);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/token')
                ? sessionResponse()
                : request.url.path.endsWith('/create_account_link')
                ? '33333333-3333-4333-8333-333333333333'
                : null,
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(() async {
      account.configure(null);
      await auth.events.close();
      await cloud.dispose();
      await legacy.dispose();
    });
    await account.configureFirebase(auth, cloud, legacy);
    auth.currentUser = auth.user;
    await expectLater(
      account.refreshVerification(),
      throwsA(isA<AuthException>()),
    );
    expect(
      legacyPaths,
      isEmpty,
      reason: 'An email alone must not access the old account.',
    );
    await account.refreshVerification(previousPassword: 'previous-password');
    expect(
      legacyPaths,
      containsAllInOrder([
        '/auth/v1/token',
        '/rest/v1/rpc/create_account_link',
      ]),
    );
    expect(account.userId, testOwner);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'account.firebase.firebase-fixture'});
    expect(prefs.getString('account.firebase.firebase-fixture'), testOwner);
  });
}
