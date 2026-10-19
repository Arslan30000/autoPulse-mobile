import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/core/widgets/health_score_widget.dart';
import 'package:autopulse_ai/core/widgets/live_obd_view.dart';
import 'package:autopulse_ai/core/widgets/telemetry_gauge.dart';
import 'package:autopulse_ai/core/widgets/vehicle_illustration.dart';
import 'package:autopulse_ai/main.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/screens/auth/login_screen.dart';
import 'package:autopulse_ai/screens/health/vehicle_health_screen.dart';
import 'package:autopulse_ai/screens/home/home_screen.dart';
import 'package:autopulse_ai/screens/onboarding/onboarding_screen.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/services/onboarding_service.dart';

import 'obd/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (!const bool.fromEnvironment('UPDATE_UI_PREVIEWS')) return;
    final configFile = File('.dart_tool/package_config.json');
    final packages =
        (jsonDecode(await configFile.readAsString())
                as Map<String, dynamic>)['packages']
            as List;
    final flutter = packages.cast<Map<String, dynamic>>().firstWhere(
      (p) => p['name'] == 'flutter',
    );
    final root = configFile.absolute.uri.resolve('${flutter['rootUri']}/');
    final fonts = root.resolve('../../bin/cache/artifacts/material_fonts/');
    final inter = FontLoader('Inter');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await inter.load();
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final bytes = await File.fromUri(fonts.resolve(entry.value))
          .readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AccountService.instance.configure(null);
  });

  void phone(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final boundaryKey = GlobalKey();
  Widget app(Widget screen) => RepaintBoundary(
    key: boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: screen,
      routes: {
        AppRouter.login: (_) => const LoginScreen(),
        AppRouter.diagnostics: (_) =>
            const Scaffold(body: Text('Diagnostics destination')),
      },
    ),
  );

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('UPDATE_UI_PREVIEWS')) return;
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/adapter-setup.png'),
        boundaryKey.currentContext!,
      );
      if (!boundaryKey.currentContext!.mounted) return;
      await precacheImage(
        const AssetImage('assets/branding/assistant.png'),
        boundaryKey.currentContext!,
      );
    });
    await tester.pump(const Duration(milliseconds: 250));
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await Directory('docs/ui').create(recursive: true);
      await File('docs/ui/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('onboarding at $width completes once and persists', (
      tester,
    ) async {
      phone(tester, width);
      await tester.pumpWidget(app(const OnboardingScreen()));
      await tester.pumpAndSettle();
      await capture(tester, 'welcome-${width.round()}');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Set up your adapter'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'adapter-${width.round()}');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Meet your AI assistant'), findsOneWidget);
      await capture(tester, 'assistant-${width.round()}');
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(await OnboardingService.isComplete(), isTrue);
      expect(find.text('Login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('auth at $width remains usable with keyboard and large text', (
      tester,
    ) async {
      phone(tester, width);
      await tester.pumpWidget(app(const LoginScreen()));
      await tester.pumpAndSettle();
      await capture(tester, 'login-${width.round()}');
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Confirm password'),
        findsOneWidget,
      );
      await capture(tester, 'register-${width.round()}');
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextFormField, 'Confirm password');
      await tester.ensureVisible(field);
      await tester.showKeyboard(field);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Continue without an account'));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets('returning installation skips onboarding', (tester) async {
    phone(tester, 390);
    SharedPreferences.setMockInitialValues({
      OnboardingService.completedKey: true,
    });
    await tester.pumpWidget(const AutoPulseApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('home scrolls across vehicle and opens diagnostics list', (
    tester,
  ) async {
    phone(tester, 390);
    ObdController.instance.setVehicle(
      const Vehicle(make: 'Toyota', model: 'Yaris', year: 2020),
    );
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(HealthScoreWidget), findsNothing);
    expect(find.byType(TelemetryGauge), findsNothing);
    await capture(tester, 'home-390');
    await tester.drag(find.byType(VehicleIllustration), const Offset(0, -280));
    await tester.pumpAndSettle();
    await capture(tester, 'home-toolkit-390');
    await tester.ensureVisible(find.text('Diagnostics'));
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnostics destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('live monitor has three disconnected gauges', (tester) async {
    phone(tester, 390);
    final transport = FakeBluetoothTransport();
    final obd = ObdController(
      transport: transport,
      repository: MemoryRecordingRepository(),
      observeLifecycle: false,
    );
    await tester.pumpWidget(
      app(LiveObdView(title: 'Live Monitor', controller: obd)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TelemetryGauge), findsNWidgets(3));
    for (final gauge in tester.widgetList<TelemetryGauge>(
      find.byType(TelemetryGauge),
    )) {
      expect(gauge.value, isNull);
      expect(gauge.quality, 'Disconnected');
    }
    await capture(tester, 'live-390');
    await tester.pumpWidget(const SizedBox.shrink());
    obd.dispose();
    await tester.pumpAndSettle();
    await transport.close();
    expect(tester.takeException(), isNull);
  });

  testWidgets('health keeps its own score', (tester) async {
    phone(tester, 390);
    await tester.pumpWidget(app(const VehicleHealthScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(HealthScoreWidget), findsOneWidget);
    await capture(tester, 'health-390');
    expect(tester.takeException(), isNull);
  });
}
