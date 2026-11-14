import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/core/widgets/dtc_alert_host.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/obd_dtc.dart';
import 'package:autopulse_ai/screens/diagnostics/diagnostics_screen.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBluetoothTransport transport;
  late ObdController controller;
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    transport = FakeBluetoothTransport()..automatic = true;
    transport.reply = (command) => command == '03'
        ? '7E8 04 43 01 03 00'
        : transport.defaultReply(command);
    controller = ObdController(
      transport: transport,
      repository: MemoryRecordingRepository(),
      observeLifecycle: false,
    );
  });
  tearDown(() async {
    await controller.disconnect();
    controller.dispose();
    await transport.close();
  });

  if (const bool.fromEnvironment('UPDATE_DTC_PREVIEWS')) {
    testWidgets('DTC screen visual preview', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(414, 896);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fonts = FontLoader('Inter');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        fonts.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
      }
      await fonts.load();
      final packageConfig = File('.dart_tool/package_config.json');
      final packages =
          (jsonDecode(packageConfig.readAsStringSync())
                  as Map<String, dynamic>)['packages']
              as List;
      final flutter = packages.cast<Map<String, dynamic>>().firstWhere(
        (p) => p['name'] == 'flutter',
      );
      final flutterRoot = packageConfig.absolute.uri.resolve(
        '${flutter['rootUri']}/',
      );
      final iconBytes = File.fromUri(
        flutterRoot.resolve(
          '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ),
      ).readAsBytesSync();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: DiagnosticsScreen(controller: controller),
          ),
        ),
      );
      await tester.runAsync(() async {
        await controller.connect(const ObdDevice(name: 'ELM', address: 'test'));
        await waitUntil(() => controller.diagnostics.alertRevision == 1);
      });
      await tester.pump();
      for (final name in ['overview', 'codes']) {
        if (name == 'codes') {
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/dtc-previews').create(recursive: true);
          await File('build/dtc-previews/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.runAsync(() => controller.disconnect());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    });
  }

  for (final width in [320.0, 414.0]) {
    testWidgets('offline and live scan layout at $width, enlarged text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: DiagnosticsScreen(controller: controller),
        ),
      );
      expect(find.text('Connect to scan'), findsOneWidget);
      expect(find.text('Status not available'), findsOneWidget);
      await tester.runAsync(() async {
        await controller.connect(const ObdDevice(name: 'ELM', address: 'test'));
        await waitUntil(
          () =>
              controller.diagnostics
                      .snapshot(
                        // First kind is stored; wait for the entire scan as well.
                        DtcKind.stored,
                      )
                      .readAt !=
                  null &&
              !controller.diagnostics.scanning,
        );
      });
      await tester.pump();
      expect(find.text('ECU reported: OFF'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('P0300'), 200);
      expect(find.text('P0300'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => controller.disconnect());
      await tester.pump();
      expect(find.text('Previous reading'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    });
  }

  testWidgets('app-wide alert can open codes, dismiss, and suppress repeats', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DtcAlertHost(
          monitor: controller.diagnostics,
          onViewCodes: () => opened++,
          child: const Scaffold(body: Text('Dashboard')),
        ),
      ),
    );
    await tester.runAsync(() async {
      await controller.connect(const ObdDevice(name: 'ELM', address: 'test'));
      await waitUntil(() => controller.diagnostics.alertRevision == 1);
    });
    await tester.pump();
    expect(find.text('Diagnostic codes detected'), findsOneWidget);
    expect(find.text('P0300'), findsOneWidget);
    await tester.tap(find.text('View codes'));
    await tester.pump();
    expect(opened, 1);
    expect(find.text('Diagnostic codes detected'), findsNothing);
    await tester.runAsync(() => controller.diagnostics.scan());
    await tester.pump();
    expect(find.text('Diagnostic codes detected'), findsNothing);
    transport.reply = (command) => command == '03'
        ? '7E8 04 43 01 01 71'
        : transport.defaultReply(command);
    await tester.runAsync(() => controller.diagnostics.scan());
    await tester.pump();
    expect(find.text('P0171'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss diagnostic alert'));
    await tester.pump();
    expect(find.text('Diagnostic codes detected'), findsNothing);
    await tester.runAsync(() => controller.disconnect());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
