import 'dart:io';
import 'dart:ui' as ui;

import 'package:autopulse_ai/core/widgets/obd_telemetry_chart.dart';
import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  final previewKey = GlobalKey();
  setUpAll(() async {
    if (!const bool.fromEnvironment('UPDATE_GRAPH_PREVIEWS')) return;
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))).load();
  });

  Widget screen(
    List<ObdSample> samples, {
    bool live = false,
    ObdParameter parameter = ObdParameter.rpm,
  }) => RepaintBoundary(
    key: previewKey,
    child: MaterialApp(
      theme: AppTheme.darkTheme,
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
    ),
  );

  testWidgets('overview remains continuous and zoom reveals raw readings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final samples = List.generate(5034, (index) {
      final time = DateTime.utc(2026).add(Duration(milliseconds: index * 800));
      return ObdSample(
        parameter: ObdParameter.rpm,
        value: 800.0 + (index % 97) * 20,
        status: ObdSampleStatus.valid,
        requestedAt: time,
        receivedAt: time,
        latencyMs: 0,
      );
    });
    await tester.pumpWidget(screen(samples));
    await tester.pumpAndSettle();
    var chart = tester.widget<LineChart>(find.byType(LineChart));
    var line = chart.data.lineBarsData.single;
    expect(line.spots.any((spot) => spot.isNull()), isFalse);
    expect(line.spots.length, lessThanOrEqualTo(1800));
    expect(find.textContaining('5034 valid readings in view'), findsOneWidget);
    final overviewXs = line.spots.map((spot) => spot.x).toSet();
    final hiddenIndex = List.generate(
      100,
      (i) => i + 2500,
    ).firstWhere((i) => !overviewXs.contains(i * .8));

    if (const bool.fromEnvironment('UPDATE_GRAPH_PREVIEWS')) {
      await tester.runAsync(() async {
        final boundary =
            previewKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('artifacts/telemetry-continuous-overview.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final width = tester.getSize(find.byType(LineChart)).width - 70;
    final start = hiddenIndex * .8 - 5;
    chart.transformationConfig.transformationController!.value =
        Matrix4.identity()
          ..translateByDouble(-start / chart.data.maxX * width * 128, 0, 0, 1)
          ..scaleByDouble(128, 128, 1, 1);
    await tester.pumpAndSettle();
    chart = tester.widget<LineChart>(find.byType(LineChart));
    line = chart.data.lineBarsData.single;
    expect(line.spots.any((spot) => spot.isNull()), isFalse);
    expect(
      line.spots,
      contains(FlSpot(hiddenIndex * .8, samples[hiddenIndex].value!)),
    );
    expect(line.spots.length, lessThan(45));
    final target = line.spots.firstWhere((spot) => spot.x == hiddenIndex * .8);
    final tooltip = chart.data.lineTouchData.touchTooltipData.getTooltipItems([
      LineBarSpot(line, 0, target),
    ]).single!;
    expect(
      tooltip.text,
      contains('${samples[hiddenIndex].value!.round()} rpm'),
    );
    expect(chart.data.titlesData.leftTitles.sideTitles.maxIncluded, isFalse);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Reset view'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5034 valid readings in view'), findsOneWidget);
  });

  testWidgets('isolated real readings remain visible between genuine gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen([
        fixtureSample(0),
        fixtureSample(1),
        fixtureSample(10),
        fixtureSample(20),
        fixtureSample(21),
      ]),
    );
    await tester.pumpAndSettle();
    final line = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData
        .single;
    expect(line.spots.where((spot) => spot.isNull()), hasLength(2));
    expect(line.dotData.checkToShowDot(const FlSpot(10.1, 1010), line), isTrue);
    expect(line.dotData.checkToShowDot(const FlSpot(.1, 1000), line), isFalse);
    expect(tester.takeException(), isNull);
  });

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
      expect(line.spots.where((spot) => spot.isNull()).length, 1);
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

  testWidgets(
    'a new connection clears a paused graph from the previous drive',
    (tester) async {
      await tester.pumpWidget(
        screen([fixtureSample(0), fixtureSample(1)], live: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause graph'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(screen([], live: true));
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Pause graph'), findsOneWidget);
    },
  );
}
