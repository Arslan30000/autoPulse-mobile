import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/screens/auth/login_screen.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/account_data_service.dart';

import 'recordings/supabase_recording_repository_test.dart'
    show sessionResponse, testOwner;

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AccountService.instance.configure(null);
    AccountDataService.instance.resolvedOwner = null;
  });
  tearDown(() {
    AccountService.instance.configure(null);
  });
  Widget app() => MaterialApp(
    home: const LoginScreen(),
    routes: {
      AppRouter.main: (_) => const Scaffold(body: Text('Home destination')),
      AppRouter.addVehicle: (_) =>
          const Scaffold(body: Text('Add car destination')),
    },
  );
  SupabaseClient backend({
    bool hasCar = true,
    bool confirmation = false,
    List<http.Request>? requests,
  }) {
    final client = SupabaseClient(
      'https://fixture.supabase.co',
      'public-test-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        requests?.add(request);
        Object response;
        if (request.url.path.endsWith('/signup')) {
          response = confirmation
              ? sessionResponse()['user']!
              : sessionResponse();
        } else if (request.url.path.endsWith('/token') ||
            request.url.path.endsWith('/verify')) {
          response = sessionResponse();
        } else if (request.url.path.endsWith('/user')) {
          response = sessionResponse()['user']!;
        } else if (request.url.path.endsWith('/recover')) {
          response = <String, dynamic>{};
        } else if (request.url.path.endsWith('/vehicles')) {
          response = hasCar
              ? [
                  {
                    'id': '33333333-3333-4333-8333-333333333333',
                    'owner_id': testOwner,
                    'make': 'Toyota',
                    'model': 'Yaris',
                    'year': 2020,
                    'vin': null,
                  },
                ]
              : [];
        } else {
          response = [];
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    AccountService.instance.configure(client);
    addTearDown(
      () => TestWidgetsFlutterBinding.ensureInitialized().runAsync(
        client.dispose,
      ),
    );
    return client;
  }

  testWidgets(
    'unconfigured builds still show login, signup and offline choices',
    (tester) async {
      await tester.pumpWidget(app());
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.text('Continue without an account'), findsOneWidget);
      await tester.ensureVisible(find.text('Create an account'));
      await tester.tap(find.text('Create an account'));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Your name'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue without an account'));
      await tester.tap(find.text('Continue without an account'));
      await tester.pumpAndSettle();
      expect(find.text('Add car destination'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  for (final hasCar in [true, false]) {
    testWidgets(
      'sign in routes ${hasCar ? 'returning owner home' : 'new owner to add car'}',
      (tester) async {
        await tester.runAsync(() async => backend(hasCar: hasCar));
        await tester.pumpWidget(app());
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'fixture@example.test',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'fixture',
        );
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Sign in'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await tester.pumpAndSettle();
        expect(
          find.text(hasCar ? 'Home destination' : 'Add car destination'),
          findsOneWidget,
        );
        expect(AccountService.instance.userId, testOwner);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets('signup rejects mismatched passwords before contacting backend', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await tester.runAsync(() async => backend(requests: requests));
    await tester.pumpWidget(app());
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Synthetic owner',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'fixture@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'fixture-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'different-password',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(requests, isEmpty);
    expect(AccountService.instance.userId, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'password recovery verifies emailed token before updating password',
    (tester) async {
      final requests = <http.Request>[];
      await tester.runAsync(() async => backend(requests: requests));
      await tester.pumpWidget(app());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'fixture@example.test',
      );
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send recovery code'));
      await tester.tap(find.text('Send recovery code'));
      await tester.pumpAndSettle();
      expect(requests.single.url.path, endsWith('/recover'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Recovery code'),
        '123456',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'replacement-password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'replacement-password',
      );
      await tester.ensureVisible(find.text('Update password'));
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(requests.map((r) => r.url.path.split('/').last), [
        'recover',
        'verify',
        'user',
      ]);
      expect(jsonDecode(requests[1].body)['type'], 'recovery');
      expect(jsonDecode(requests[2].body)['password'], 'replacement-password');
      expect(find.text('Continue'), findsOneWidget);
      expect(
        find.text('Password updated. Continue to your account.'),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('signup sends display name and waits for email confirmation', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await tester.runAsync(
      () async => backend(confirmation: true, requests: requests),
    );
    await tester.pumpWidget(app());
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Synthetic owner',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'fixture@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'fixture-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'fixture-password',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(
      find.text('Check your email to confirm your account, then sign in here.'),
      findsOneWidget,
    );
    expect(AccountService.instance.userId, isNull);
    expect(
      jsonDecode(requests.single.body)['data']['display_name'],
      'Synthetic owner',
    );
    expect(find.text('Home destination'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
