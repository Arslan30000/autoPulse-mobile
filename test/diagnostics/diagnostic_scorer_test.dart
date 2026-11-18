import 'dart:convert';
import 'dart:io';

import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/diagnostics/diagnostic_scorer.dart';
import 'package:autopulse_ai/services/diagnostics/vehicle_diagnostics.dart';
import 'package:autopulse_ai/services/driving_context/context_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ECU evidence fails closed and faults override complete scans', () {
    expect(diagnosticTrainingGate(null), 'unverified');
    expect(diagnosticTrainingGate({'complete': false}), 'unverified');
    expect(
      diagnosticTrainingGate({'complete': true, 'blocked': true}),
      'fault',
    );
    expect(
      diagnosticTrainingGate({'complete': true, 'blocked': false}),
      'clean',
    );
  });

  test('ridge learns supported windows and persistence resets after a gap', () {
    DiagnosticWindow window(int i, double maf) => DiagnosticWindow(
      i,
      DateTime.utc(2026).add(Duration(seconds: i * 5)),
      'idling:ordinary:initial',
      [1, .3, 0, .1, 0],
      {16: maf},
      {
        for (final pid in diagnosticSignals.keys)
          pid: pid == 16 ? 'valid' : 'missing',
      },
    );
    final baseline = [for (var i = 0; i < 40; i++) window(i, 3)];
    final models = fitDiagnosticReference(baseline);
    expect(models.keys, ['16']);
    expect(scoreDiagnosticWindows(baseline, models)['events'], isEmpty);
    final gap = [window(4, 12), window(5, 12), window(7, 12)];
    expect(scoreDiagnosticWindows(gap, models)['events'], isEmpty);
    final alert = scoreDiagnosticWindows([
      ...gap,
      window(8, 12),
      window(9, 12),
    ], models);
    expect(alert['events'], hasLength(1));
    expect(
      alert['events'][0]['detected_at'],
      window(9, 12).at.toIso8601String(),
    );
    expect(alert['checks']['5']['scored'], 0);
  });

  final fixtureDir = Platform.environment['AUTOPULSE_DIAGNOSTIC_REPLAY'];
  if (fixtureDir == null) return;
  final files =
      Directory(fixtureDir)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    test('Python parity: ${file.uri.pathSegments.last}', () {
      final fixture = jsonDecode(file.readAsStringSync()) as Map;
      final model = ForestContextEvaluator.fromJson(
        jsonEncode(fixture['context_model']),
        allowExperimental: true,
      );
      final samples = (fixture['samples'] as List).map((raw) {
        final row = raw as List;
        final at = DateTime.parse(row[1] as String);
        return ObdSample(
          parameter: signalParameter(row[0] as int),
          receivedAt: at,
          requestedAt: at,
          status: ObdSampleStatus.values.byName(row[3] as String),
          value: (row[2] as num?)?.toDouble(),
          latencyMs: 0,
        );
      }).toList();
      final stopwatch = Stopwatch()..start();
      final windows = diagnosticWindows(samples, model);
      final actual = <String, double>{};
      final report = scoreDiagnosticWindows(
        windows,
        fixture['models'] as Map,
        onScored: (window, pid, expected) =>
            actual['${window.index}:$pid'] = expected,
      );
      stopwatch.stop();
      final expected = fixture['expected'] as Map;
      final trace = fixture['trace'] as List;
      expect(actual.length, trace.length);
      for (final item in trace) {
        final key = '${item[0]}:${item[1]}';
        expect(
          actual[key],
          closeTo((item[2] as num).toDouble(), 1e-8),
          reason: key,
        );
      }
      expect(report['windows'], expected['windows']);
      Set<String> events(Map report) => {
        for (final event in report['events'] as List)
          '${event['pid']}:${DateTime.parse(event['detected_at'] as String).microsecondsSinceEpoch}',
      };
      expect(events(report), events(expected));
      stdout.writeln(
        'Parity: ${samples.length} samples, ${trace.length} predictions, '
        '${events(report).length} events, ${stopwatch.elapsedMilliseconds} ms',
      );
    });
  }
}
