import 'dart:math' as math;

import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/driving_context/context_evaluator.dart';
import 'package:autopulse_ai/services/driving_context/context_features.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';

const diagnosticSignals = <int, (double, int, double, double)>{
  16: (1, 3, 0, 655.35),
  5: (4, 6, -40, 215),
  15: (5, 6, -40, 215),
  6: (5, 4, -100, 99.22),
  7: (4, 6, -100, 99.22),
};

ObdParameter signalParameter(int pid) =>
    ObdParameter.values.firstWhere((parameter) => parameter.pid == pid);

class DiagnosticWindow {
  const DiagnosticWindow(
    this.index,
    this.at,
    this.context,
    this.inputs,
    this.values,
    this.quality,
  );
  final int index;
  final DateTime at;
  final String? context;
  final List<double> inputs;
  final Map<int, double> values;
  final Map<int, String> quality;
}

List<DiagnosticWindow> diagnosticWindows(
  List<ObdSample> input,
  ContextEvaluator evaluator,
) {
  if (input.isEmpty) return [];
  // Preserve acquisition order when timestamps tie.
  final samples = input.indexed.toList()
    ..sort((a, b) {
      final order = a.$2.receivedAt.compareTo(b.$2.receivedAt);
      return order == 0 ? a.$1.compareTo(b.$1) : order;
    });
  final controller = DrivingContextController(evaluator: evaluator)
    ..reset(connected: true);
  final buffer = ContextFeatureBuffer();
  final latest = <int, ObdSample>{};
  final origin = samples.first.$2.receivedAt.toUtc();
  final end = samples.last.$2.receivedAt.toUtc();
  final windows = <DiagnosticWindow>[];
  var cursor = 0;
  var previousBucket = -1;
  try {
    for (var at = origin; ;) {
      while (cursor < samples.length &&
          !samples[cursor].$2.receivedAt.isAfter(at)) {
        final sample = samples[cursor++].$2;
        buffer.add(sample);
        controller.accept(sample);
        latest[sample.parameter.pid] = sample;
      }
      controller.expire(at);
      final elapsed = at.difference(origin).inMicroseconds / 1e6;
      final bucket = elapsed ~/ 5;
      if (bucket != previousBucket) {
        previousBucket = bucket;
        final values = <int, double>{};
        final quality = <int, String>{};
        for (final entry in diagnosticSignals.entries) {
          final sample = latest[entry.key];
          final value = sample?.value;
          var status = sample?.status.name ?? 'missing';
          if (sample != null &&
              at.difference(sample.receivedAt).inSeconds >= 5) {
            status = 'stale';
          } else if (status == 'valid') {
            if (value == null ||
                !value.isFinite ||
                value < entry.value.$3 ||
                value > entry.value.$4) {
              status = 'invalid';
            } else {
              values[entry.key] = value;
            }
          }
          quality[entry.key] = status;
        }
        final state = controller.current;
        final features = buffer.extract(at);
        final supported =
            features != null &&
            state.state.isOperating &&
            state.state.name != 'engineOff';
        windows.add(
          DiagnosticWindow(
            bucket,
            at,
            supported
                ? '${state.state.name}:${state.highDemand ? 'demand' : 'ordinary'}:${elapsed < 600 ? 'initial' : 'later'}'
                : null,
            supported
                ? [
                    1,
                    features.rpm / 3000,
                    features.speed / 120,
                    features.values[3] / 100,
                    math.min(elapsed, 600) / 600,
                  ]
                : [],
            values,
            quality,
          ),
        );
      }
      if (at == end) break;
      final next = at.add(const Duration(seconds: 1));
      at = next.isAfter(end) ? end : next;
    }
  } finally {
    controller.dispose();
  }
  return windows;
}

String diagnosticGroup(String context, int pid) =>
    pid == 16 ? context.substring(0, context.lastIndexOf(':')) : context;

double diagnosticExpected(Map model, List<double> x) {
  final coefficients = model['coef'] as List;
  var value = 0.0;
  for (var i = 0; i < x.length; i++) {
    value += (coefficients[i] as num) * x[i];
  }
  return value;
}

List<double> _ridge(List<DiagnosticWindow> rows, int pid) {
  const size = 5;
  final a = List.generate(size, (_) => List.filled(size + 1, 0.0));
  for (final row in rows) {
    for (var i = 0; i < size; i++) {
      for (var j = 0; j < size; j++) {
        a[i][j] += row.inputs[i] * row.inputs[j];
      }
      a[i][size] += row.inputs[i] * row.values[pid]!;
    }
  }
  for (var i = 0; i < size; i++) {
    a[i][i] += .2;
  }
  for (var col = 0; col < size; col++) {
    var pivot = col;
    for (var r = col + 1; r < size; r++) {
      if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
    }
    final swap = a[pivot];
    a[pivot] = a[col];
    a[col] = swap;
    final scale = a[col][col];
    for (var j = col; j <= size; j++) {
      a[col][j] /= scale;
    }
    for (var r = 0; r < size; r++) {
      if (r == col) continue;
      final factor = a[r][col];
      for (var j = col; j <= size; j++) {
        a[r][j] -= factor * a[col][j];
      }
    }
  }
  return [for (final row in a) row.last];
}

/// A candidate only. The caller qualifies its source using ECU scan evidence.
Map<String, dynamic> fitDiagnosticReference(List<DiagnosticWindow> windows) {
  final models = <String, dynamic>{};
  for (final entry in diagnosticSignals.entries) {
    final pid = entry.key;
    final groups = <String, List<DiagnosticWindow>>{};
    for (final window in windows) {
      final context = window.context;
      if (context == null || !window.values.containsKey(pid)) continue;
      groups.putIfAbsent(diagnosticGroup(context, pid), () => []).add(window);
    }
    final fitted = <String, dynamic>{};
    for (final group in groups.entries) {
      final rows = group.value;
      if (rows.length < 30) continue;
      final model = <String, dynamic>{'coef': _ridge(rows, pid)};
      final residuals =
          rows
              .map(
                (w) => (w.values[pid]! - diagnosticExpected(model, w.inputs))
                    .abs(),
              )
              .toList()
            ..sort();
      model['threshold'] = math.max(
        entry.value.$1,
        residuals[(.99 * residuals.length).ceil() - 1],
      );
      model['windows'] = rows.length;
      fitted[group.key] = model;
    }
    if (fitted.isNotEmpty) models['$pid'] = fitted;
  }
  return models;
}

Map<String, dynamic> scoreDiagnosticWindows(
  List<DiagnosticWindow> windows,
  Map models, {
  void Function(DiagnosticWindow, int, double)? onScored,
}) {
  final checks = <String, dynamic>{};
  final events = <Map<String, dynamic>>[];
  for (final signal in diagnosticSignals.entries) {
    final pid = signal.key;
    final parameter = signalParameter(pid);
    var scored = 0, valid = 0, count = 0, lastIndex = -2;
    String? lastContext, lastDirection;
    var absoluteError = 0.0;
    final quality = <String, int>{};
    final observedByContext = <String, List<double>>{};
    final referenceByContext = <String, Map<String, dynamic>>{};
    Map<String, dynamic>? event;
    for (final window in windows) {
      final reason = window.quality[pid]!;
      quality.update(reason, (n) => n + 1, ifAbsent: () => 1);
      final observed = window.values[pid];
      if (observed != null) valid++;
      final context = window.context;
      if (observed != null) {
        observedByContext.putIfAbsent(context ?? 'all', () => []).add(observed);
      }
      final model = context == null
          ? null
          : (models['$pid'] as Map?)?[diagnosticGroup(context, pid)] as Map?;
      if (observed == null || model == null || context == null) {
        count = 0;
        continue;
      }
      final expected = diagnosticExpected(model, window.inputs);
      final delta = observed - expected;
      final threshold = (model['threshold'] as num).toDouble();
      referenceByContext[context] = {
        'low': expected - threshold,
        'high': expected + threshold,
        'value': observed,
        'at': window.at.toIso8601String(),
      };
      scored++;
      absoluteError += delta.abs();
      onScored?.call(window, pid, expected);
      if (delta.abs() <= threshold) {
        count = 0;
        continue;
      }
      final direction = delta > 0 ? 'high' : 'low';
      if (count == 0 ||
          lastIndex != window.index - 1 ||
          lastContext != context ||
          lastDirection != direction) {
        count = 0;
        event = {
          'pid': pid,
          'signal': parameter.label,
          'unit': parameter.unit,
          'direction': direction,
          'context': context,
          'started_at': window.at.toIso8601String(),
          'suggested_check': switch (pid) {
            16 => 'Inspect the intake duct, air filter and airflow sensor connector.',
            5 => 'Review the warm-up trace and the vehicle cooling-system service checks.',
            15 => 'Compare stationary heat soak with moving readings and inspect the intake temperature connector.',
            _ => 'Compare both fuel trims at warm idle and steady cruise. Review ECU codes before checking intake and fuel delivery.',
          },
          'related_session_codes': <Object>[],
        };
      }
      count++;
      lastIndex = window.index;
      lastContext = context;
      lastDirection = direction;
      if (count >= signal.value.$2) {
        event!.addAll({
          'ended_at': window.at.toIso8601String(),
          'observed': double.parse(observed.toStringAsFixed(3)),
          'expected': double.parse(expected.toStringAsFixed(3)),
          'threshold': double.parse(threshold.toStringAsFixed(3)),
        });
        if (count == signal.value.$2) {
          event['detected_at'] = window.at.toIso8601String();
          events.add(event);
        }
      }
    }
    checks['$pid'] = {
      'name': parameter.label,
      'scored': scored,
      'valid': valid,
      'mae': scored == 0 ? null : absoluteError / scored,
      'quality': quality,
      'unit': parameter.unit,
      'ranges': {
        for (final entry in observedByContext.entries)
          if (entry.value.length >= 5) entry.key: _observedRange(entry.value),
      },
      'reference_ranges': referenceByContext,
    };
  }
  events.sort(
    (a, b) =>
        (a['detected_at'] as String).compareTo(b['detected_at'] as String),
  );
  return {'windows': windows.length, 'checks': checks, 'events': events};
}

Map<String, dynamic> _observedRange(List<double> values) {
  final latest = values.last;
  values.sort();
  return {
    'low': values[((values.length - 1) * .1).round()],
    'high': values[((values.length - 1) * .9).round()],
    'value': latest,
    'count': values.length,
  };
}
