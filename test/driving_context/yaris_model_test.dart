import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/core/widgets/driving_context_card.dart';
import 'package:autopulse_ai/models/driving_context.dart';
import 'package:autopulse_ai/services/driving_context/context_evaluator.dart';
import 'package:autopulse_ai/services/driving_context/context_features.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';

import 'helpers.dart';

const yarisModelPath =
    'assets/ml/driving_context/context-weak-yaris-v1-forest-40-depth6.json';
void main() {
  final json = File(yarisModelPath).readAsStringSync();
  final parity = jsonDecode(
    File('test/fixtures/driving_context_yaris_model_parity.json')
        .readAsStringSync(),
  ) as Map;
  test('weakly supervised Yaris artifact requires opt-in and retains genuine label provenance', () {
    expect(() => ForestContextEvaluator.fromJson(json), throwsFormatException);
    final model = ForestContextEvaluator.fromJson(
      json,
      allowExperimental: true,
    );
    expect(model.source, ContextSource.experimentalModel);
    final metadata = jsonDecode(json) as Map;
    expect(metadata['reviewed_labels'], false);
    expect(metadata['experimental'], true);
    final provenance = metadata['provenance'] as Map;
    expect(
      (provenance['training_sessions'] as List).toSet().intersection(
        (provenance['test_sessions'] as List).toSet(),
      ),
      isEmpty,
    );
  });
  test('Yaris-trained forest matches all Python probability references and physical fallbacks', () {
    final model = ForestContextEvaluator.fromJson(
      json,
      allowExperimental: true,
    );
    expect(model.version, parity['model_version']);
    for (final row in parity['predictions'] as List) {
      final features = ContextFeatures(
        (row['values'] as List).map((x) => (x as num).toDouble()).toList(),
        contextEpoch,
        contextEpoch,
      );
      expect(
        model.votes(features),
        orderedEquals(
          (row['votes'] as List).map(
            (x) => closeTo((x as num).toDouble(), 1e-12),
          ),
        ),
      );
      expect(model.evaluate(features, DrivingState.reading).name, row['state']);
    }
  });
  for (final width in [320.0, 414.0]) {
    testWidgets(
      'real trained artifact updates the card live and discloses weak-label status at $width',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = ForestContextEvaluator.fromJson(
          json,
          allowExperimental: true,
        );
        final c = DrivingContextController(evaluator: model)
          ..reset(connected: true);
        for (var i = 0; i < 12; i++) {
          frame(c, i, speed: 40, load: 90, throttle: 40);
        }
        expect(c.current.state, DrivingState.heavyLoad);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DrivingContextCard(controller: c),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Heavy Load'), findsOneWidget);
        expect(
          find.text('Live estimate · Experimental model + rules'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      },
    );
  }
}
