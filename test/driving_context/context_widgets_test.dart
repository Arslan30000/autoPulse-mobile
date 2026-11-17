import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/core/widgets/context_change_banner.dart';
import 'package:autopulse_ai/core/widgets/driving_context_card.dart';
import 'package:autopulse_ai/core/widgets/dtc_alert_host.dart';
import 'package:autopulse_ai/models/driving_context.dart';
import 'package:autopulse_ai/screens/health/vehicle_health_screen.dart';
import 'package:autopulse_ai/services/driving_context/context_model_loader.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';
import 'package:autopulse_ai/services/obd/dtc_monitor.dart';
import 'package:autopulse_ai/services/obd/elm327_client.dart';

import '../obd/fakes.dart';
import 'helpers.dart';

void cruise(DrivingContextController c) {
  for (var i = 0; i < 10; i++) {
    frame(c, i);
  }
}

void heavy(DrivingContextController c) {
  for (var i = 10; i < 20; i++) {
    frame(c, i, load: 90);
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  test(
    'packaged registry loads the explicitly experimental Yaris model',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final model = await ContextModelLoader.load();
      expect(model, isNotNull);
      expect(model!.source, ContextSource.experimentalModel);
      expect(model.version, 'context-weak-yaris-v1-forest-40-depth6');
    },
  );
  test(
    'model registry rejects path traversal and synthetic test artifacts',
    () async {
      final fixture = jsonDecode(
        File('test/fixtures/driving_context_parity.json').readAsStringSync(),
      ) as Map;
      for (final path in [
        '../test/fixtures/model.json',
        'assets/ml/driving_context/test-only.json',
      ]) {
        final bundle = _ModelBundle({
          'assets/ml/registry.json': jsonEncode({
            'schema_version': 1,
            'driving_context': path,
          }),
          'assets/ml/driving_context/test-only.json': jsonEncode(
            fixture['model'],
          ),
        });
        await expectLater(
          ContextModelLoader.load(bundle: bundle),
          throwsFormatException,
        );
      }
    },
  );

  testWidgets(
    'context banner passes taps through, expires and cancels on disconnect',
    (tester) async {
      final c = DrivingContextController()..reset(connected: true);
      addTearDown(c.dispose);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Stack(
            children: [
              Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: 180,
                    width: 300,
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Dashboard action'),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: ContextChangeBanner(controller: c)),
            ],
          ),
        ),
      );
      cruise(c);
      heavy(c);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Driving context: Heavy Load'), findsOneWidget);
      await tester.tap(find.text('Dashboard action'));
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 3300));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Driving context: Heavy Load'), findsNothing);
      c.reset();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DTC warnings preempt context notices and dismissed warnings do not replay old notices',
    (tester) async {
      final c = DrivingContextController()..reset(connected: true);
      final monitor = _TestDtcMonitor();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: DtcAlertHost(
            monitor: monitor,
            onViewCodes: () {},
            passiveAlert: ContextChangeBanner(controller: c),
            child: const Scaffold(body: Text('Dashboard')),
          ),
        ),
      );
      cruise(c);
      heavy(c);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Driving context: Heavy Load'), findsOneWidget);
      monitor.showWarning();
      await tester.pump();
      expect(find.text('Diagnostic codes detected'), findsOneWidget);
      expect(find.text('Driving context: Heavy Load'), findsNothing);
      await tester.tap(find.byTooltip('Dismiss diagnostic alert'));
      await tester.pump();
      expect(find.text('Driving context: Heavy Load'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      monitor.dispose();
      c.dispose();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 414.0]) {
    testWidgets(
      'health card wraps at $width with large text and reduced motion',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = DrivingContextController()..reset(connected: true);
        addTearDown(c.dispose);
        cruise(c);
        heavy(c);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: VehicleHealthScreen(contextController: c),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(DrivingContextCard));
        expect(find.text('Heavy Load'), findsOneWidget);
        expect(find.text('Live estimate · Provisional rules'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'disposing or replacing an active banner cancels timers; reduced motion is supported',
    (tester) async {
      final a = DrivingContextController()..reset(connected: true);
      final b = DrivingContextController()..reset(connected: true);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      Widget host(DrivingContextController c) => MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ContextChangeBanner(controller: c),
      );
      await tester.pumpWidget(host(a));
      cruise(a);
      heavy(a);
      await tester.pump();
      expect(find.text('Driving context: Heavy Load'), findsOneWidget);
      await tester.pumpWidget(host(b));
      await tester.pump();
      expect(find.text('Driving context: Heavy Load'), findsNothing);
      cruise(b);
      heavy(b);
      await tester.pump();
      b.reset();
      await tester.pump();
      expect(find.text('Driving context: Heavy Load'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  if (const bool.fromEnvironment('UPDATE_CONTEXT_PREVIEWS')) {
    testWidgets('capture context health and notification visual evidence', (
      tester,
    ) async {
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
      final config = File('.dart_tool/package_config.json');
      final packages =
          (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
      final flutter = packages.cast<Map>().firstWhere(
        (p) => p['name'] == 'flutter',
      );
      final root = config.absolute.uri.resolve('${flutter['rootUri']}/');
      final bytes = File.fromUri(
        root.resolve(
          '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ),
      ).readAsBytesSync();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0, 414.0]) {
        tester.view.physicalSize = Size(width, 1000);
        final c = DrivingContextController()..reset(connected: true);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              home: Stack(
                children: [
                  VehicleHealthScreen(contextController: c),
                  Positioned.fill(child: ContextChangeBanner(controller: c)),
                ],
              ),
            ),
          ),
        );
        cruise(c);
        await tester.pumpAndSettle();
        for (final state in ['cruise', 'heavy-banner']) {
          if (state == 'heavy-banner') {
            heavy(c);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
          }
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/driving-context-previews')
                .create(recursive: true);
            await File(
              'build/driving-context-previews/$state-${width.round()}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _ModelBundle extends CachingAssetBundle {
  _ModelBundle(this.files);
  final Map<String, String> files;
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(files[key]!)));
}

class _TestDtcMonitor extends DtcMonitor {
  _TestDtcMonitor()
    : super(
        client: Elm327Client(FakeBluetoothTransport()),
        isReady: () => false,
        ecuSource: () => null,
      );
  void showWarning() {
    alertCodes = const ['P0300'];
    alertRevision++;
    notifyListeners();
  }
}
