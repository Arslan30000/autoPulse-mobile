import 'package:flutter/foundation.dart';
import 'package:autopulse_ai/models/driving_context.dart';
import 'package:autopulse_ai/models/obd.dart';

import 'context_evaluator.dart';
import 'context_features.dart';

/// Receives only accepted OBD attempts. A UI timer may expire data, never confirm it.
class DrivingContextController extends ChangeNotifier {
  DrivingContextController({ContextEvaluator? evaluator})
    : _evaluator = evaluator ?? const RulesContextEvaluator();
  ContextEvaluator _evaluator;
  final _buffer = ContextFeatureBuffer();
  var _current = const DrivingContextSnapshot(state: DrivingState.disconnected);
  ContextNotice? _notice;
  DrivingContextSnapshot get current => _current;
  ContextNotice? get notice => _notice;
  DrivingState? _pending;
  bool _pendingDemand = false, _connected = false, _disposed = false;
  DateTime? _pendingAt, _lastEvidence, _lastLoadEvidence, _lastNotice;
  int _loadEvidence = 0, _revision = 0;
  DateTime? _firstAttempt;

  void reset({bool connected = false}) {
    if (_disposed) return;
    _connected = connected;
    _buffer.clear();
    _pending = null;
    _pendingAt = null;
    _lastEvidence = null;
    _lastLoadEvidence = null;
    _lastNotice = null;
    _loadEvidence = 0;
    _firstAttempt = null;
    _notice = null;
    _current = DrivingContextSnapshot(
      state: connected ? DrivingState.reading : DrivingState.disconnected,
      source: _evaluator.source,
      modelVersion: _evaluator.version,
    );
    notifyListeners();
  }

  /// Call with an explicitly reviewed artifact; changing models resets history.
  void useEvaluator(ContextEvaluator evaluator) {
    _evaluator = evaluator;
    reset(connected: _connected);
  }

  void accept(ObdSample sample) {
    if (!_connected || _disposed) return;
    _firstAttempt ??= sample.receivedAt;
    _buffer.add(sample);
    _evaluate(sample.receivedAt, freshEvidence: true);
  }

  void expire(DateTime now) {
    if (_connected && !_disposed) _evaluate(now, freshEvidence: false);
  }

  void _unavailable(DateTime now) {
    _pending = null;
    _pendingAt = null;
    _loadEvidence = 0;
    _notice = null;
    if (current.state == DrivingState.insufficient) return;
    // Initial partial input remains a useful 'Reading context' until first estimate.
    if (current.state == DrivingState.reading &&
        _lastEvidence == null &&
        (_firstAttempt == null ||
            now.difference(_firstAttempt!) < const Duration(seconds: 10))) {
      return;
    }
    _current = DrivingContextSnapshot(
      state: DrivingState.insufficient,
      updatedAt: now,
      source: _evaluator.source,
      modelVersion: _evaluator.version,
    );
    notifyListeners();
  }

  void _evaluate(DateTime now, {required bool freshEvidence}) {
    final features = _buffer.extract(now);
    if (features == null) {
      _unavailable(now);
      return;
    }
    if (!freshEvidence ||
        (_lastEvidence != null && !features.speedAt.isAfter(_lastEvidence!))) {
      return;
    }
    _lastEvidence = features.speedAt;
    final next = _evaluator.evaluate(features, current.state);
    if (!next.isOperating) {
      _unavailable(now);
      return;
    }
    final demand =
        features.speed > 1 && features.load >= (current.highDemand ? 72 : 80);
    if (next == current.state && demand == current.highDemand) {
      _pending = null;
      _pendingAt = null;
      return;
    }
    if (_pending != next || _pendingDemand != demand) {
      _pending = next;
      _pendingDemand = demand;
      _pendingAt = features.speedAt;
      _loadEvidence = 1;
      _lastLoadEvidence = features.loadAt;
      return;
    }
    if (features.loadAt != _lastLoadEvidence) {
      _loadEvidence++;
      _lastLoadEvidence = features.loadAt;
    }
    final wait = demand
        ? const Duration(seconds: 5)
        : const Duration(seconds: 2);
    if (features.speedAt.difference(_pendingAt!) < wait ||
        (demand && _loadEvidence < 2)) {
      return;
    }
    final wasOperating = current.state.isOperating;
    final changed = current.state != next;
    final newDemand = demand && !current.highDemand;
    _current = DrivingContextSnapshot(
      state: next,
      highDemand: demand,
      source: _evaluator.source,
      modelVersion: _evaluator.version,
      updatedAt: now,
    );
    _pending = null;
    _pendingAt = null;
    // Initial/recovered classifications are quiet. No backlog of routine notices.
    if (wasOperating &&
        ((changed && next.significant) || newDemand) &&
        (_lastNotice == null ||
            now.difference(_lastNotice!) >= const Duration(seconds: 25))) {
      _lastNotice = now;
      _notice = ContextNotice(
        ++_revision,
        newDemand && !next.significant
            ? DrivingContextSnapshot(
                state: DrivingState.heavyLoad,
                highDemand: true,
                source: current.source,
                modelVersion: current.modelVersion,
                updatedAt: now,
              )
            : current,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _buffer.clear();
    super.dispose();
  }
}
