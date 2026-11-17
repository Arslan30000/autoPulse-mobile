import 'dart:convert';
import 'dart:typed_data';

import 'package:autopulse_ai/models/driving_context.dart';

import 'context_features.dart';

abstract interface class ContextEvaluator {
  ContextSource get source;
  String? get version;
  DrivingState evaluate(ContextFeatures features, DrivingState previous);
}

/// Provisional thresholds, versioned and replayable. No learned accuracy claim.
class RulesContextEvaluator implements ContextEvaluator {
  const RulesContextEvaluator();
  @override
  ContextSource get source => ContextSource.rules;
  @override
  String get version => 'rules-v1';
  @override
  DrivingState evaluate(ContextFeatures f, DrivingState previous) {
    if (f.speed <= (previous == DrivingState.idling ? 2 : 1)) {
      return f.rpm < 200 ? DrivingState.engineOff : DrivingState.idling;
    }
    if (f.rpm < 200) return DrivingState.insufficient;
    if (f.acceleration <=
        (previous == DrivingState.decelerating ? -.35 : -.55)) {
      return DrivingState.decelerating;
    }
    if (f.acceleration >=
            (previous == DrivingState.aggressiveAcceleration ? 1.2 : 1.5) &&
        f.load >= 60 &&
        f.values[3] >= 25) {
      return DrivingState.aggressiveAcceleration;
    }
    if (f.acceleration >= (previous == DrivingState.accelerating ? .15 : .25)) {
      return DrivingState.accelerating;
    }
    if (f.load >= (previous == DrivingState.heavyLoad ? 72 : 80)) {
      return DrivingState.heavyLoad;
    }
    return f.speed >= (previous == DrivingState.highwayCruising ? 75 : 80)
        ? DrivingState.highwayCruising
        : DrivingState.cityCruising;
  }
}

/// Bounded, portable forest. Weakly supervised models require explicit opt-in.
class ForestContextEvaluator implements ContextEvaluator {
  ForestContextEvaluator._(this._model);
  final Map<String, dynamic> _model;
  static const maxTrees = 50;
  @override
  ContextSource get source => _model['experimental'] == true
      ? ContextSource.experimentalModel
      : ContextSource.model;
  @override
  String get version => _model['version'] as String;

  factory ForestContextEvaluator.fromJson(
    String json, {
    bool allowExperimental = false,
  }) {
    if (json.length > 2000000) {
      throw const FormatException('Context model too large');
    }
    final m = jsonDecode(json) as Map<String, dynamic>;
    final reviewed = m['reviewed_labels'] == true && m['experimental'] != true;
    final experimental =
        allowExperimental &&
        m['experimental'] == true &&
        m['reviewed_labels'] == false &&
        m['label_source'] == 'telemetry-weak-v1';
    if (m['schema_version'] != 1 ||
        m['task'] != 'driving_context' ||
        (!reviewed && !experimental) ||
        m['version'] is! String ||
        (m['version'] as String).isEmpty ||
        jsonEncode(m['features']) != jsonEncode(contextFeatureNames)) {
      throw const FormatException('Incompatible or unreviewed context model');
    }
    final classes = List<String>.from(m['classes'] as List);
    final allowed = DrivingState.values
        .where((s) => s.index >= DrivingState.cityCruising.index)
        .map((s) => s.name)
        .toSet();
    if (classes.length < 2 ||
        classes.toSet().length != classes.length ||
        !classes.every(allowed.contains)) {
      throw const FormatException('Invalid context classes');
    }
    final trees = m['trees'] as List;
    if (trees.isEmpty || trees.length > maxTrees) {
      throw const FormatException('Invalid tree count');
    }
    for (final raw in trees) {
      final nodes = raw as List;
      if (nodes.isEmpty || nodes.length > 127) {
        throw const FormatException('Invalid tree size');
      }
      final visited = <int>{};
      void check(int index, int depth) {
        if (index < 0 ||
            index >= nodes.length ||
            depth > 6 ||
            !visited.add(index)) {
          throw const FormatException('Invalid tree structure');
        }
        final n = nodes[index] as Map<String, dynamic>;
        if (n.containsKey('votes')) {
          final votes = List<num>.from(n['votes'] as List);
          if (votes.length != classes.length ||
              votes.any((v) => !v.isFinite || v < 0) ||
              (votes.fold<double>(0, (a, b) => a + b) - 1).abs() > 1e-6) {
            throw const FormatException('Invalid leaf distribution');
          }
        } else {
          final f = n['feature'] as int;
          if (f < 0 ||
              f >= contextFeatureNames.length ||
              !(n['threshold'] as num).isFinite) {
            throw const FormatException('Invalid tree split');
          }
          check(n['left'] as int, depth + 1);
          check(n['right'] as int, depth + 1);
        }
      }

      check(0, 0);
      if (visited.length != nodes.length) {
        throw const FormatException('Unreachable nodes');
      }
    }
    return ForestContextEvaluator._(m);
  }

  /// Averaged leaf distributions, not a calibrated confidence percentage.
  List<double> votes(ContextFeatures f) {
    if (f.values.length != contextFeatureNames.length ||
        f.values.any((x) => !x.isFinite)) {
      throw const FormatException('Invalid context feature vector');
    }
    final result = List<double>.filled((_model['classes'] as List).length, 0);
    // sklearn converts prediction inputs to float32 before comparing splits.
    final inputs = Float32List.fromList(f.values);
    for (final tree in _model['trees'] as List) {
      final nodes = tree as List;
      var index = 0;
      while (!(nodes[index] as Map).containsKey('votes')) {
        final n = nodes[index] as Map;
        index = inputs[n['feature'] as int] <= (n['threshold'] as num)
            ? n['left'] as int
            : n['right'] as int;
      }
      final leaf = (nodes[index] as Map)['votes'] as List;
      for (var j = 0; j < result.length; j++) {
        result[j] += (leaf[j] as num) / (_model['trees'] as List).length;
      }
    }
    return result;
  }

  @override
  DrivingState evaluate(ContextFeatures f, DrivingState previous) {
    // Stationary/engine-off and direction checks remain physical guardrails.
    final rule = const RulesContextEvaluator().evaluate(f, previous);
    if (f.speed <= 2 || f.rpm < 200) return rule;
    // Missing classes remain explicit physical-rule fallbacks, not pretend ML.
    if (!(_model['classes'] as List).contains(rule.name)) return rule;
    final distribution = votes(f);
    var best = 0;
    for (var i = 1; i < distribution.length; i++) {
      if (distribution[i] > distribution[best]) best = i;
    }
    if (distribution[best] < .6) {
      // This opt-in prototype is deliberately a model + rules hybrid. Preserve
      // live context through gaps in weak-label training coverage without
      // presenting fallback decisions as independently validated ML accuracy.
      return _model['experimental'] == true ? rule : DrivingState.insufficient;
    }
    final state = DrivingState.values.byName(
      (_model['classes'] as List)[best] as String,
    );
    if (state == DrivingState.aggressiveAcceleration &&
        (f.acceleration < 1.2 || f.load < 60 || f.values[3] < 25)) {
      return rule;
    }
    if (state == DrivingState.decelerating && f.acceleration > -.35) {
      return rule;
    }
    if (state == DrivingState.heavyLoad && f.load < 72) return rule;
    return state;
  }
}
