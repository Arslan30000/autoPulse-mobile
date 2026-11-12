import 'dart:math' as math;

import 'package:autopulse_ai/models/obd.dart';

/// Continuity is determined from acquisition data, before any plot reduction.
/// Every retained point is an actual reading, including the extrema of a bucket.
class TelemetrySeries {
  final DateTime origin;
  final List<List<ObdSample>> segments = [];
  int validCount = 0;
  int missingCount = 0;
  int timeGapCount = 0;
  int clockResetCount = 0;
  double minX = 0;
  double maxX = 1;
  double minValue = double.infinity;
  double maxValue = double.negativeInfinity;

  TelemetrySeries(List<ObdSample> samples, this.origin) {
    DateTime? previous;
    List<ObdSample>? segment;
    for (final sample in samples) {
      final x = seconds(sample);
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      if (previous != null) {
        final gap = sample.receivedAt.difference(previous);
        if (gap > const Duration(seconds: 6)) {
          timeGapCount++;
          segment = null;
        } else if (gap.isNegative) {
          clockResetCount++;
          segment = null;
        }
      }
      previous = sample.receivedAt;
      if (sample.status != ObdSampleStatus.valid ||
          sample.value == null ||
          !sample.value!.isFinite) {
        missingCount++;
        segment = null;
        continue;
      }
      validCount++;
      minValue = math.min(minValue, sample.value!);
      maxValue = math.max(maxValue, sample.value!);
      if (segment == null) {
        segment = [];
        segments.add(segment);
      }
      segment.add(sample);
    }
    maxX = math.max(maxX, minX + 1);
  }

  double seconds(ObdSample sample) =>
      sample.receivedAt.difference(origin).inMicroseconds / 1000000;

  int _lowerBound(List<ObdSample> samples, double x, {bool inclusive = false}) {
    var low = 0;
    var high = samples.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      final time = seconds(samples[middle]);
      if (time < x || (inclusive && time == x)) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  TelemetryViewport viewport(
    double from,
    double to, {
    int maximumPoints = 1800,
  }) {
    if (maximumPoints < 4) throw ArgumentError.value(maximumPoints);
    final windows = <List<ObdSample>>[];
    var visibleCount = 0;
    var candidateCount = 0;
    for (final segment in segments) {
      if (seconds(segment.last) < from || seconds(segment.first) > to) continue;
      final first = _lowerBound(segment, from);
      final last = _lowerBound(segment, to, inclusive: true);
      visibleCount += last - first;
      // Keep one neighbour on each side so lines clip at the viewport edges.
      final window = segment.sublist(
        math.max(0, first - 1),
        math.min(segment.length, last + 1),
      );
      windows.add(window);
      candidateCount += window.length;
    }
    return TelemetryViewport([
      for (final window in windows)
        _envelope(
          window,
          math.max(
            4,
            (maximumPoints * window.length / math.max(1, candidateCount))
                .floor(),
          ),
        ),
    ], visibleCount);
  }

  List<ObdSample> _envelope(List<ObdSample> samples, int maximum) {
    if (samples.length <= maximum) return samples;
    final bucketSize = (samples.length / (maximum ~/ 4)).ceil();
    final selected = <int>{};
    for (var start = 0; start < samples.length; start += bucketSize) {
      final end = math.min(start + bucketSize, samples.length);
      var minIndex = start;
      var maxIndex = start;
      for (var i = start + 1; i < end; i++) {
        if (samples[i].value! < samples[minIndex].value!) minIndex = i;
        if (samples[i].value! > samples[maxIndex].value!) maxIndex = i;
      }
      selected.addAll([start, end - 1, minIndex, maxIndex]);
    }
    final indices = selected.toList()..sort();
    return [for (final index in indices) samples[index]];
  }
}

class TelemetryViewport {
  final List<List<ObdSample>> segments;
  final int visibleCount;
  const TelemetryViewport(this.segments, this.visibleCount);
  int get plottedCount =>
      segments.fold(0, (sum, segment) => sum + segment.length);
}
