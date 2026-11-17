import 'dart:math' as math;

import 'package:autopulse_ai/models/obd.dart';

/// Keep this ordered schema identical to ml/driving_context/features.py.
const contextFeatureNames = [
  'speed_kph',
  'rpm',
  'load_pct',
  'throttle_pct',
  'acceleration_m_s2',
  'speed_range_kph',
  'rpm_range',
  'throttle_range_pct',
];

class ContextFeatures {
  const ContextFeatures(this.values, this.speedAt, this.loadAt);
  final List<double> values;
  final DateTime speedAt;
  final DateTime loadAt;
  double get speed => values[0];
  double get rpm => values[1];
  double get load => values[2];
  double get acceleration => values[4];
}

/// Causal, bounded buffer. Latest failed attempts invalidate an older good value.
class ContextFeatureBuffer {
  static const core = [
    ObdParameter.speed,
    ObdParameter.rpm,
    ObdParameter.load,
    ObdParameter.throttle,
  ];
  final _latest = <ObdParameter, ObdSample>{};
  final _history = <ObdParameter, List<ObdSample>>{};

  void clear() {
    _latest.clear();
    _history.clear();
  }

  void add(ObdSample sample) {
    if (!core.contains(sample.parameter)) return;
    final old = _latest[sample.parameter];
    if (old != null && !sample.receivedAt.isAfter(old.receivedAt)) return;
    _latest[sample.parameter] = sample;
    final history = _history.putIfAbsent(sample.parameter, () => []);
    history.add(sample);
    final start = sample.receivedAt.subtract(const Duration(seconds: 5));
    history.removeWhere((s) => s.receivedAt.isBefore(start));
    // A malformed/high-rate source cannot grow the buffer without bound.
    if (history.length > 100) history.removeRange(0, history.length - 100);
  }

  static bool valid(ObdSample s) {
    final value = s.value;
    if (s.status != ObdSampleStatus.valid || value == null || !value.isFinite) {
      return false;
    }
    final max = switch (s.parameter) {
      ObdParameter.speed => 255.0,
      ObdParameter.rpm => 16383.75,
      _ => 100.0,
    };
    return value >= 0 && value <= max;
  }

  ContextFeatures? extract(DateTime now) {
    for (final p in core) {
      final s = _latest[p];
      final age = s == null
          ? null
          : now.difference(s.receivedAt).inMicroseconds / 1e6;
      final limit = p == ObdParameter.speed || p == ObdParameter.rpm ? 3 : 5;
      if (s == null || !valid(s) || age! < 0 || age > limit) return null;
    }
    List<ObdSample> recent(ObdParameter p) => (_history[p] ?? [])
        .where(
          (s) =>
              !s.receivedAt.isAfter(now) &&
              now.difference(s.receivedAt) <= const Duration(seconds: 5),
        )
        .toList();
    final speeds = recent(ObdParameter.speed);
    // Never take a derivative over failed attempts or a long acquisition gap.
    if (speeds.length < 3 || speeds.any((s) => !valid(s))) return null;
    for (var i = 1; i < speeds.length; i++) {
      if (speeds[i].receivedAt.difference(speeds[i - 1].receivedAt) >
          const Duration(seconds: 3)) {
        return null;
      }
    }
    final origin = speeds.first.receivedAt;
    if (speeds.last.receivedAt.difference(origin).inMilliseconds < 1500) {
      return null;
    }
    final xs = speeds
        .map((s) => s.receivedAt.difference(origin).inMicroseconds / 1e6)
        .toList();
    final ys = speeds.map((s) => s.value! / 3.6).toList();
    final mx = xs.reduce((a, b) => a + b) / xs.length;
    final my = ys.reduce((a, b) => a + b) / ys.length;
    var covariance = 0.0, variance = 0.0;
    for (var i = 0; i < xs.length; i++) {
      covariance += (xs[i] - mx) * (ys[i] - my);
      variance += math.pow(xs[i] - mx, 2).toDouble();
    }
    if (variance <= 0) return null;
    double range(ObdParameter p) {
      final values = recent(p).where(valid).map((s) => s.value!).toList();
      return values.reduce(math.max) - values.reduce(math.min);
    }

    return ContextFeatures(
      List.unmodifiable([
        _latest[ObdParameter.speed]!.value!,
        _latest[ObdParameter.rpm]!.value!,
        _latest[ObdParameter.load]!.value!,
        _latest[ObdParameter.throttle]!.value!,
        covariance / variance,
        range(ObdParameter.speed),
        range(ObdParameter.rpm),
        range(ObdParameter.throttle),
      ]),
      _latest[ObdParameter.speed]!.receivedAt,
      _latest[ObdParameter.load]!.receivedAt,
    );
  }
}
