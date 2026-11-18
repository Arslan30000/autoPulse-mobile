import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/obd_dtc.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/driving_context/context_evaluator.dart';
import 'package:autopulse_ai/services/driving_context/context_model_loader.dart';
import 'package:autopulse_ai/services/obd/dtc_monitor.dart';

import 'diagnostic_scorer.dart';

Map<String, dynamic> diagnosticScan(DtcMonitor monitor, DateTime since) {
  final milAt = monitor.milReadAt;
  final freshMil = milAt != null && !milAt.isBefore(since);
  final codes = <Map<String, String>>[];
  var complete =
      freshMil &&
      monitor.milError == null &&
      monitor.milOn != null &&
      monitor.storedCount != null &&
      !monitor.scanning;
  for (final kind in DtcKind.values) {
    final snapshot = monitor.snapshot(kind);
    final at = snapshot.readAt;
    if (at == null || at.isBefore(since) || snapshot.error != null) {
      complete = false;
      continue;
    }
    for (final code in snapshot.codes) {
      codes.add({
        'code': code.code,
        'status': kind.label,
        'scan_time': code.readAt.toUtc().toIso8601String(),
      });
    }
  }
  return {
    'complete': complete,
    'blocked':
        codes.isNotEmpty ||
        (freshMil &&
            ((monitor.milOn ?? false) || (monitor.storedCount ?? 0) > 0)),
    'codes': codes,
  };
}

String diagnosticTrainingGate(Map? evidence) {
  if (evidence?['blocked'] == true) return 'fault';
  if (evidence?['complete'] == true) return 'clean';
  return 'unverified';
}

class VehicleDiagnostics extends ChangeNotifier {
  VehicleDiagnostics(
    this.store, {
    String? Function()? owner,
    this.contextOverride,
  }) : _owner = owner ?? (() => AccountService.instance.userId);
  static VehicleDiagnostics? instance;
  final SqliteObdRecordingRepository store;
  final String? Function() _owner;
  final ContextEvaluator? contextOverride;
  Future<void> _queue = Future.value();
  Future<void>? _sweep;
  bool _rescan = false;
  late final _evaluator = ContextModelLoader.load().then<ContextEvaluator>(
    (model) => model ?? const RulesContextEvaluator(),
    onError: (Object _) => const RulesContextEvaluator(),
  );
  bool running = false;
  String? error;

  Future<void> attachScan(int id, Map<String, dynamic> evidence) async {
    final db = await store.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO diagnostic_scans (session_id, payload) VALUES (?, ?)',
      [id, jsonEncode(evidence)],
    );
  }

  Future<void> refresh() {
    if (_sweep case final current?) {
      _rescan = true;
      return current;
    }
    return _sweep = _drain().whenComplete(() => _sweep = null);
  }

  Future<void> _drain() async {
    do {
      _rescan = false;
      await _refresh();
    } while (_rescan);
  }

  Future<void> _refresh() async {
    final owner = _owner();
    running = true;
    error = null;
    notifyListeners();
    try {
      var cursor = 0;
      while (_owner() == owner) {
        final runs = await store.listRecordings(
          owner,
          beforeId: cursor,
          limit: 25,
          ascending: true,
        );
        if (runs.isEmpty) break;
        for (final run in runs) {
          if (_owner() != owner) return;
          if (run.endedAt != null) await evaluate(run.id);
        }
        cursor = runs.last.id;
      }
    } catch (e) {
      debugPrint('Diagnostic history check failed: ${e.runtimeType}');
      error = 'Some recordings could not be checked. Try again from Diagnostic History.';
    } finally {
      running = false;
      notifyListeners();
    }
  }

  Future<void> evaluate(int id) {
    final owner = _owner();
    return _queue = _queue.then((_) async {
      if (_owner() != owner) return;
      try {
        await _evaluate(id, owner);
      } catch (e) {
        error = 'A recording could not be analyzed. Try refreshing its report.';
        debugPrint('Recording diagnostic failed: ${e.runtimeType}');
      }
      notifyListeners();
    });
  }

  bool _visible(ObdRecording run, String? owner) =>
      run.ownerId == null || run.ownerId == owner;

  Future<List<ObdRecording>> visibleRecordings(int cursor) async {
    final owner = _owner();
    final runs = await store.listRecordings(owner, beforeId: cursor);
    return _owner() == owner ? runs : [];
  }

  Future<void> evaluateRestored(String cloudId, String owner) async {
    if (_owner() != owner) return;
    final rows = await (await store.database).query(
      'sessions',
      columns: ['id'],
      where: 'cloud_id = ? AND owner_id = ?',
      whereArgs: [cloudId, owner],
    );
    if (_owner() == owner && rows.isNotEmpty) {
      await evaluate(rows.single['id'] as int);
    }
  }

  String _referenceKey(ObdRecording run) =>
      '${run.ownerId ?? 'offline'}:${run.vehicle?.id ?? 'unknown'}';

  Future<void> _evaluate(int id, String? owner) async {
    final db = await store.database;
    final run = await store.recording(id);
    if (!_visible(run, owner) || run.endedAt == null) return;
    final key = _referenceKey(run);
    final references = await db.query(
      'diagnostic_references',
      where: 'vehicle_key = ?',
      whereArgs: [key],
    );
    final version = references.isEmpty
        ? 0
        : references.single['version'] as int;
    final cached = await db.query(
      'diagnostic_results',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    final previous = cached.isEmpty
        ? null
        : jsonDecode(cached.single['payload'] as String) as Map;
    if (previous?['range_schema'] == 1 &&
        previous?['vehicle_key'] == key &&
        (cached.single['version'] == version ||
            previous?['reference'] == true ||
            (previous?['checks'] as Map?)?.values.any(
                  (c) => (c['scored'] as int) > 0,
                ) ==
                true)) {
      return;
    }
    final models = references.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(references.single['payload'] as String)
              as Map<String, dynamic>;
    final scans = await db.query(
      'diagnostic_scans',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    final evidence = scans.isEmpty
        ? null
        : jsonDecode(scans.single['payload'] as String) as Map;
    final gate = diagnosticTrainingGate(evidence);
    final samples = <ObdSample>[];
    for (var cursor = 0; ;) {
      if (_owner() != owner) return;
      final page = await store.samples(id, afterId: cursor, limit: 1000);
      if (page.isEmpty) break;
      samples.addAll(page.map((recorded) => recorded.sample));
      cursor = page.last.id;
    }
    final vehicle = run.vehicle;
    final isYaris =
        vehicle?.make.toLowerCase() == 'toyota' &&
        vehicle!.model.toLowerCase().contains('yaris');
    final evaluator =
        contextOverride ??
        (isYaris ? await _evaluator : const RulesContextEvaluator());
    // Keep parsing, feature replay and fitting off the Flutter UI isolate.
    final timer = Stopwatch()..start();
    final wasReference = previous?['reference'] == true;
    final analysis = await compute(_runDiagnostics, (
      samples,
      evaluator,
      wasReference ? <String, dynamic>{} : models,
      gate == 'clean' && run.vehicle?.id != null && previous == null,
    ));
    timer.stop();
    if (kDebugMode) {
      debugPrint(
        'Diagnostic replay: ${samples.length} samples, ${timer.elapsedMilliseconds} ms including isolate dispatch.',
      );
    }
    final report = analysis.$1;
    final updated = analysis.$2;
    final nextVersion = updated == null ? version : version + 1;
    final events = report['events'] as List<Map<String, dynamic>>;
    final codes = (evidence?['codes'] as List?) ?? [];
    for (final event in events) {
      final pid = event['pid'];
      event['related_session_codes'] = codes.where((item) {
        final code = item['code'] as String;
        return switch (pid) {
          16 => code.startsWith('P010'),
          5 =>
            code.startsWith('P011') && code.compareTo('P0115') >= 0 ||
                code == 'P0128',
          15 => code.startsWith('P011') && code.compareTo('P0115') < 0,
          _ => code == 'P0171' || code == 'P0172',
        };
      }).toList();
    }
    final checks = report['checks'] as Map;
    final hasCoverage = checks.values.any(
      (check) => (check['scored'] as int) > 0,
    );
    report.addAll({
      'session': run.cloudId,
      'vehicle': run.vehicleName,
      'vehicle_key': key,
      'started_at': run.startedAt.toIso8601String(),
      'dtc_gate': gate,
      'dtc_evidence': codes,
      'model_version': version,
      'reference': wasReference || updated != null,
      'reference_version': wasReference
          ? (previous?['reference_version'])
          : nextVersion,
      'range_schema': 1,
      'context_model': evaluator.version,
      'status': events.isNotEmpty
          ? 'Needs review'
          : hasCoverage
          ? 'Checked'
          : models.isEmpty
          ? 'Learning baseline'
          : 'Insufficient data',
    });
    await db.transaction((tx) async {
      if (_owner() != owner) return;
      final current = await tx.query(
        'sessions',
        columns: ['owner_id', 'vehicle_id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (current.isEmpty ||
          current.single['owner_id'] != run.ownerId ||
          current.single['vehicle_id'] != run.vehicle?.id) {
        return;
      }
      if (updated != null) {
        await tx.rawInsert(
          'INSERT OR REPLACE INTO diagnostic_references '
          '(vehicle_key, version, payload) VALUES (?, ?, ?)',
          [key, nextVersion, jsonEncode(updated)],
        );
      }
      await tx.rawInsert(
        'INSERT OR REPLACE INTO diagnostic_results '
        '(session_id, version, payload) VALUES (?, ?, ?)',
        [id, nextVersion, jsonEncode(report)],
      );
    });
  }

  Future<Map<String, dynamic>?> result(int id) async {
    final owner = _owner();
    final run = await store.recording(id);
    if (!_visible(run, owner)) return null;
    final rows = await (await store.database).query(
      'diagnostic_results',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty || _owner() != owner) return null;
    final report =
        jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>;
    if (report['vehicle_key'] != _referenceKey(run) ||
        report['range_schema'] != 1) {
      return null;
    }
    final earlier = await (await store.database).rawQuery(
      '''
      SELECT d.payload FROM diagnostic_results d JOIN sessions s ON s.id = d.session_id
      WHERE s.id <> ? AND s.vehicle_id = ? AND s.owner_id IS ?
        AND julianday(s.started_at) < julianday(?)
      ORDER BY julianday(s.started_at) DESC, s.id DESC LIMIT 12
    ''',
      [id, run.vehicle?.id, run.ownerId, run.startedAt.toIso8601String()],
    );
    if (_owner() != owner) return null;
    final prior = <String, Map<String, dynamic>>{};
    for (final row in earlier) {
      final old = jsonDecode(row['payload'] as String) as Map;
      if (old['vehicle_key'] != _referenceKey(run)) continue;
      for (final entry in (old['checks'] as Map).entries) {
        final ranges = entry.value['ranges'] as Map?;
        if (ranges == null) continue;
        final signal = prior.putIfAbsent(entry.key as String, () => {});
        for (final range in ranges.entries) {
          signal.putIfAbsent(
            range.key as String,
            () => {...range.value as Map, 'started_at': old['started_at']},
          );
        }
      }
    }
    return {...report, 'previous_ranges': prior};
  }
}

(Map<String, dynamic>, Map<String, dynamic>?) _runDiagnostics(
  (List<ObdSample>, ContextEvaluator, Map<String, dynamic>, bool) input,
) {
  final (samples, evaluator, active, eligible) = input;
  final windows = diagnosticWindows(samples, evaluator);
  final report = scoreDiagnosticWindows(windows, active);
  if (!eligible || (report['events'] as List).isNotEmpty) return (report, null);
  // Add supported contexts and permit limited centering around the initial model.
  final fitted = fitDiagnosticReference(windows);
  final updated = <String, dynamic>{...active};
  var changed = false;
  for (final entry in fitted.entries) {
    final existing = <String, dynamic>{
      ...?active[entry.key] as Map<String, dynamic>?,
    };
    for (final group in (entry.value as Map<String, dynamic>).entries) {
      final old = existing[group.key] as Map?;
      if (old == null) {
        existing[group.key] = group.value;
        changed = true;
        continue;
      }
      final pid = int.parse(entry.key);
      final residuals = <double>[
        for (final window in windows)
          if (window.context != null &&
              window.values.containsKey(pid) &&
              diagnosticGroup(window.context!, pid) == group.key)
            window.values[pid]! - diagnosticExpected(old, window.inputs),
      ]..sort();
      final middle = residuals.length ~/ 2;
      final drift = residuals.length.isOdd
          ? residuals[middle]
          : (residuals[middle - 1] + residuals[middle]) / 2;
      final threshold = (old['threshold'] as num).toDouble();
      if (drift.abs() > .5 * threshold || drift.abs() < .05 * threshold) {
        continue;
      }
      final coefficients = List<double>.from(old['coef'] as List);
      final anchor = (old['anchor'] as num?)?.toDouble() ?? coefficients[0];
      final next = math.max(
        anchor - .25 * threshold,
        math.min(anchor + .25 * threshold, coefficients[0] + .2 * drift),
      );
      if ((next - coefficients[0]).abs() < 1e-9) continue;
      coefficients[0] = next;
      existing[group.key] = {...old, 'coef': coefficients, 'anchor': anchor};
      changed = true;
    }
    updated[entry.key] = existing;
  }
  return (report, changed ? updated : null);
}
