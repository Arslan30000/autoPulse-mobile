import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/telemetry_plot.dart';
import 'package:flutter_test/flutter_test.dart';

final _origin = DateTime.utc(2026);

ObdSample _sample(int index, {double? value, bool missing = false}) {
  final time = _origin.add(Duration(milliseconds: index * 800));
  return ObdSample(
    parameter: ObdParameter.speed,
    value: missing ? null : value ?? (index % 100).toDouble(),
    status: missing ? ObdSampleStatus.noData : ObdSampleStatus.valid,
    requestedAt: time,
    receivedAt: time,
    latencyMs: 0,
  );
}

void main() {
  test('reducing 5034 continuous readings never manufactures a gap', () {
    final samples = List.generate(5034, _sample);
    final series = TelemetrySeries(samples, _origin);
    final view = series.viewport(series.minX, series.maxX);

    expect(series.validCount, 5034);
    expect(series.timeGapCount, 0);
    expect(series.missingCount, 0);
    expect(view.visibleCount, 5034);
    expect(view.plottedCount, lessThanOrEqualTo(1800));
    expect(view.segments, hasLength(1));
    expect(view.segments.single.first, same(samples.first));
    expect(view.segments.single.last, same(samples.last));
    expect(view.segments.single.any((sample) => sample.value == 0), isTrue);
    // This reproduces the old false-break trigger: selected plot points can
    // be far apart even though every raw acquisition is only 800 ms apart.
    final reduced = view.segments.single;
    expect(
      [
        for (var i = 1; i < reduced.length; i++)
          reduced[i].receivedAt.difference(reduced[i - 1].receivedAt).inSeconds,
      ].any((gap) => gap > 6),
      isTrue,
    );
  });

  test('zoom retrieves every original reading in the visible interval', () {
    final samples = List.generate(20000, _sample);
    final series = TelemetrySeries(samples, _origin);
    final view = series.viewport(1500, 1540);
    final expected = samples.where((sample) {
      final time = series.seconds(sample);
      return time >= 1500 && time <= 1540;
    }).toList();
    final displayed = view.segments.expand((segment) => segment).where((
      sample,
    ) {
      final time = series.seconds(sample);
      return time >= 1500 && time <= 1540;
    }).toList();

    expect(view.visibleCount, expected.length);
    expect(displayed, orderedEquals(expected));
    expect(view.plottedCount, lessThanOrEqualTo(expected.length + 2));
  });

  test('raw missing data, real time gaps and clock resets remain separate', () {
    final series = TelemetrySeries([
      _sample(0),
      _sample(1),
      _sample(2, missing: true),
      _sample(3),
      _sample(4),
      _sample(20),
      _sample(21),
      _sample(5),
    ], _origin);
    final view = series.viewport(series.minX, series.maxX);

    expect(series.validCount, 7);
    expect(series.missingCount, 1);
    expect(series.timeGapCount, 1);
    expect(series.clockResetCount, 1);
    expect(view.segments.map((segment) => segment.length), [2, 2, 2, 1]);
  });

  test('large overview preserves spikes and all detail remains accessible', () {
    final samples = List.generate(105120, _sample);
    samples[17000] = _sample(17000, value: 9999);
    samples[70000] = _sample(70000, value: -100);
    final series = TelemetrySeries(samples, _origin);
    final overview = series.viewport(series.minX, series.maxX);

    expect(overview.visibleCount, 105120);
    expect(overview.plottedCount, lessThanOrEqualTo(1800));
    expect(overview.segments.single, contains(samples[17000]));
    expect(overview.segments.single, contains(samples[70000]));
    final detail = series.viewport(80000, 80020);
    expect(detail.visibleCount, 26);
    expect(detail.plottedCount, 28);
    expect(series.minValue, -100);
    expect(series.maxValue, 9999);
  });
}
