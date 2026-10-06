import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autopulse_ai/core/widgets/live_obd_view.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

import 'fakes.dart';

void main() {
  for (final width in [320.0, 412.0, 1024.0]) {
    testWidgets('disconnected telemetry fits width $width', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = FakeBluetoothTransport();
      final controller = ObdController(
        transport: transport,
        repository: MemoryRecordingRepository(),
        observeLifecycle: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LiveObdView(title: 'Live monitor', controller: controller),
        ),
      );
      expect(find.text('Live monitor'), findsOneWidget);
      expect(find.text('--'), findsWidgets);
      expect(find.text('Disconnected'), findsWidgets);
      expect(find.text('780'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Record drive'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.disconnect();
      controller.dispose();
      await tester.pump(const Duration(milliseconds: 200));
      await transport.close();
    });
  }
  testWidgets('web preview explains Bluetooth is unavailable', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final transport = FakeBluetoothTransport()..isSupported = false;
    final controller = ObdController(
      transport: transport,
      repository: MemoryRecordingRepository(),
      observeLifecycle: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LiveObdView(title: 'Live monitor', controller: controller),
      ),
    );
    expect(find.textContaining('Android'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.disconnect();
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 200));
    await transport.close();
  });
}
