import 'package:autopulse_ai/core/widgets/obd_telemetry_chart.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  Widget screen(
    List<ObdSample> samples, {
    bool live = false,
    ObdParameter parameter = ObdParameter.rpm,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ObdTelemetryChart(
          samples: samples,
          parameter: parameter,
          live: live,
          timeOrigin: DateTime.utc(2026),
        ),
      ),
    ),
  );

  testWidgets(
    'axes and tooltips preserve trip time and gaps between attempts',
    (tester) async {
      await tester.pumpWidget(
        screen([
          fixtureSample(10),
          fixtureSample(11, status: ObdSampleStatus.noData),
          fixtureSample(20),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Engine RPM (rpm)'), findsOneWidget);
      expect(find.text('Elapsed time (s)'), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final line = chart.data.lineBarsData.single;
      expect(line.spots.where((spot) => spot.isNull()).length, 2);
      expect(line.spots.last.x, closeTo(20.1, 0.001));
      final tooltip = chart.data.lineTouchData.touchTooltipData.getTooltipItems(
        [LineBarSpot(line, 0, line.spots.last)],
      ).single!;
      expect(tooltip.text, contains('1020 rpm'));
      expect(tooltip.text, contains('20.10 s elapsed'));
      expect(tooltip.text, contains('.100'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pausing freezes only the graph and resuming shows new readings',
    (tester) async {
      await tester.pumpWidget(
        screen([fixtureSample(0), fixtureSample(1)], live: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause graph'));
      await tester.pumpWidget(
        screen([
          fixtureSample(0),
          fixtureSample(1),
          fixtureSample(2),
        ], live: true),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .length,
        2,
      );
      expect(
        find.text('Graph paused. Live readings and recording continue.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Resume graph'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .length,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('negative trims, zoom, reset, and labels fit a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final time = DateTime.utc(2026);
    ObdSample trim(int seconds, double value) => ObdSample(
      parameter: ObdParameter.shortTrim,
      value: value,
      status: ObdSampleStatus.valid,
      requestedAt: time.add(Duration(seconds: seconds)),
      receivedAt: time.add(Duration(seconds: seconds)),
      latencyMs: 0,
    );
    await tester.pumpWidget(
      screen([
        trim(0, -12.5),
        trim(180, 3.5),
      ], parameter: ObdParameter.shortTrim),
    );
    await tester.pumpAndSettle();
    expect(find.text('Short fuel trim B1 (%)'), findsOneWidget);
    expect(find.text('Elapsed time (min)'), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minY, lessThan(-12.5));
    final transform = chart.transformationConfig.transformationController!;
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(transform.value.getMaxScaleOnAxis(), 2);
    await tester.tap(find.text('Reset view'));
    await tester.pumpAndSettle();
    expect(transform.value.getMaxScaleOnAxis(), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all missing values explain the empty window without plotting zeros',
    (tester) async {
      await tester.pumpWidget(
        screen([fixtureSample(0, status: ObdSampleStatus.noData)]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsNothing);
      expect(
        find.text('No valid readings in this graph window.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
