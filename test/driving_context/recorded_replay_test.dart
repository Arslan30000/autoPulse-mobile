import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/driving_context/context_features.dart';
import 'package:autopulse_ai/services/driving_context/context_evaluator.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';

/// Optional local recordings stay outside Git and CI. Generate tapes with the
/// Python replay CLI, then pass --dart-define=CONTEXT_REPLAY_DIR=<output path>.
void main() {
  const path = String.fromEnvironment('CONTEXT_REPLAY_DIR');
  const modelPath = String.fromEnvironment('CONTEXT_REPLAY_MODEL');
  test(
    'Dart runtime matches Python causal replay on every recorded second',
    () {
      final tapes = Directory(path)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('-replay.jsonl'))
          .toList();
      expect(tapes, isNotEmpty);
      var seconds = 0, attempts = 0;
      final watch = Stopwatch()..start();
      for (final file in tapes) {
        final evaluator = modelPath.isEmpty
            ? null
            : ForestContextEvaluator.fromJson(
                File(modelPath).readAsStringSync(),
                allowExperimental: true,
              );
        final c = DrivingContextController(evaluator: evaluator)
          ..reset(connected: true);
        final buffer = ContextFeatureBuffer();
        for (final line in file.readAsLinesSync()) {
          final row = jsonDecode(line) as Map<String, dynamic>;
          for (final a in row['attempts'] as List) {
            final at = DateTime.parse(a['at'] as String);
            final sample = ObdSample(
              parameter: ObdParameter.values.firstWhere(
                (p) => p.pid == a['pid'],
              ),
              value: (a['value'] as num?)?.toDouble(),
              status: ObdSampleStatus.values.byName(a['quality'] as String),
              requestedAt: at,
              receivedAt: at,
              latencyMs: 0,
            );
            buffer.add(sample);
            c.accept(sample);
            attempts++;
          }
          final now = DateTime.parse(row['at'] as String);
          c.expire(now);
          final features = buffer.extract(now);
          if (row['features'] == null) {
            expect(features, isNull);
          } else {
            expect(
              features!.values,
              orderedEquals(
                (row['features'] as List).map(
                  (v) => closeTo((v as num).toDouble(), 1e-8),
                ),
              ),
            );
          }
          expect(
            c.current.state.name,
            row['state'],
            reason: '${file.path} at $now',
          );
          expect(c.current.highDemand, row['high_demand']);
          seconds++;
        }
        c.dispose();
      }
      watch.stop();
      // This measures software agreement on this computer, not driving accuracy.
      debugPrint(
        'Replay parity: ${tapes.length} sessions, $seconds evaluation ticks, $attempts attempts; ${watch.elapsedMilliseconds} ms desktop wall time.',
      );
    },
    skip: path.isEmpty
        ? 'Generate local tapes and set CONTEXT_REPLAY_DIR.'
        : false,
  );
}
