import 'dart:convert';
import 'dart:math' as math;

import 'diagnostic_scorer.dart';

Map<String, dynamic> summarizeVehicleHealth(
  Iterable<Map<String, Object?>> rows,
  int referenceVersion,
  Map<String, dynamic> models,
) {
  final contexts = <String, Map<String, Map<String, dynamic>>>{};
  final findings = <Map<String, dynamic>>[];
  var checked = 0;
  var analyzed = 0;
  for (final row in rows) {
    if (row['payload'] == null) continue;
    final report = jsonDecode(row['payload'] as String) as Map;
    if (report['vehicle_key'] != row['vehicle_key']) continue;
    analyzed++;
    final checks = report['checks'] as Map;
    if (checks.values.any((check) => (check['scored'] as int) > 0)) checked++;
    for (final checkEntry in checks.entries) {
      final check = checkEntry.value as Map;
      final ranges = check['ranges'] as Map? ?? {};
      final predictions = check['reference_ranges'] as Map? ?? {};
      for (final key in {...ranges.keys, ...predictions.keys}.cast<String>()) {
        final group = contexts.putIfAbsent(key, () => {});
        final signal = group.putIfAbsent(
          checkEntry.key as String,
          () => {
            'name': check['name'],
            'unit': check['unit'],
            'drives': 0,
            'readings': 0,
            'scored_drives': 0,
          },
        );
        if (ranges[key] case final Map range) {
          final low = range['low'] as num;
          final high = range['high'] as num;
          signal['low'] = math.min(signal['low'] as num? ?? low, low);
          signal['high'] = math.max(signal['high'] as num? ?? high, high);
          signal['drives'] = (signal['drives'] as int) + 1;
          signal['readings'] =
              (signal['readings'] as int) + (range['count'] as int);
          signal['latest'] ??= range['value'];
        }
        if (predictions[key] case final Map range) {
          signal['scored_drives'] = (signal['scored_drives'] as int) + 1;
          if (report['model_version'] == referenceVersion) {
            signal['expected'] ??= range;
          }
        }
      }
    }
    for (final event in report['events'] as List) {
      findings.add({
        ...event as Map<String, dynamic>,
        'recording_id': row['id'],
      });
    }
  }
  for (final context in contexts.entries) {
    if (context.key == 'all') continue;
    for (final entry in context.value.entries) {
      final pid = int.parse(entry.key);
      final model =
          (models[entry.key] as Map?)?[diagnosticGroup(context.key, pid)]
              as Map?;
      final inputs = model?['example_inputs'] as List?;
      if (model != null && inputs != null) {
        final expected = diagnosticExpected(model, List<double>.from(inputs));
        final threshold = model['threshold'] as num;
        entry.value['example_band'] = {
          'low': math.max(diagnosticSignals[pid]!.$3, expected - threshold),
          'high': math.min(diagnosticSignals[pid]!.$4, expected + threshold),
        };
      }
    }
  }
  findings.sort(
    (a, b) =>
        DateTime.parse(b['detected_at'] as String)
            .compareTo(DateTime.parse(a['detected_at'] as String)),
  );
  return {
    'contexts': contexts,
    'findings': findings.take(8).toList(),
    'finding_count': findings.length,
    'checked': checked,
    'analyzed': analyzed,
    'reference_version': referenceVersion,
  };
}
