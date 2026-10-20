import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autopulse_ai/core/widgets/live_obd_view.dart';
import 'package:autopulse_ai/core/widgets/telemetry_gauge.dart';
import 'package:autopulse_ai/core/widgets/obd_connection_panel.dart';
import 'package:autopulse_ai/models/obd.dart';
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
      expect(find.byType(ObdConnectionPanel), findsNothing);
      expect(find.text('At a glance'), findsNothing);
      final speed = find.byWidgetPredicate(
        (w) => w is TelemetryGauge && w.label == 'Speed',
      );
      expect(tester.getSize(speed).width, greaterThanOrEqualTo(240));
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
  testWidgets(
    'gauges distinguish valid, unsupported, stale, and NO DATA readings',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final transport = FakeBluetoothTransport();
      final controller = _GaugeController(transport);
      final now = DateTime.now();
      ObdSample sample(
        ObdParameter p,
        double? value,
        ObdSampleStatus status,
        DateTime received,
      ) => ObdSample(
        parameter: p,
        value: value,
        status: status,
        requestedAt: received,
        receivedAt: received,
        latencyMs: 20,
      );
      controller.status = ObdConnectionStatus.ready;
      controller.readings[ObdParameter.rpm] = sample(
        ObdParameter.rpm,
        1726,
        ObdSampleStatus.valid,
        now,
      );
      controller.readings[ObdParameter.coolant] = sample(
        ObdParameter.coolant,
        88,
        ObdSampleStatus.valid,
        now.subtract(const Duration(seconds: 9)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LiveObdView(title: 'Live monitor', controller: controller),
        ),
      );
      Finder gauge(String label) => find.byWidgetPredicate(
        (w) => w is TelemetryGauge && w.label == label,
      );
      expect(tester.widget<TelemetryGauge>(gauge('Engine RPM')).value, 1726);
      expect(
        tester.widget<TelemetryGauge>(gauge('Speed')).quality,
        'Not supported',
      );
      expect(tester.widget<TelemetryGauge>(gauge('Coolant')).quality, 'Stale');
      expect(tester.widget<TelemetryGauge>(gauge('Coolant')).value, isNull);
      controller.readings[ObdParameter.rpm] = sample(
        ObdParameter.rpm,
        null,
        ObdSampleStatus.noData,
        now,
      );
      controller.publish();
      await tester.pump();
      expect(tester.widget<TelemetryGauge>(gauge('Engine RPM')).value, isNull);
      expect(
        tester.widget<TelemetryGauge>(gauge('Engine RPM')).quality,
        'No data',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.pump(const Duration(milliseconds: 200));
      await transport.close();
    },
  );
  testWidgets('unsupported transport keeps live free of connection controls', (
    tester,
  ) async {
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
    expect(find.byType(ObdConnectionPanel), findsNothing);
    expect(find.text('Connect adapter'), findsNothing);
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Record drive'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.disconnect();
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 200));
    await transport.close();
  });
}

class _GaugeController extends ObdController {
  _GaugeController(FakeBluetoothTransport transport)
    : super(
        transport: transport,
        repository: MemoryRecordingRepository(),
        observeLifecycle: false,
      );
  final readings = <ObdParameter, ObdSample>{};
  @override
  Map<ObdParameter, ObdSample> get samples => readings;
  @override
  Set<ObdParameter> get supported => {ObdParameter.rpm, ObdParameter.coolant};
  void publish() => notifyListeners();
}
