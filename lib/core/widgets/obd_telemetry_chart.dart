import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:autopulse_ai/models/obd.dart';

int _tickDecimals(double interval) {
  var decimals = 0;
  while (interval < 1 && decimals < 3) {
    interval *= 10;
    decimals++;
  }
  return decimals;
}

/// Inspecting or pausing a graph never pauses acquisition or local recording.
class ObdTelemetryChart extends StatefulWidget {
  final List<ObdSample> samples;
  final ObdParameter parameter;
  final DateTime? timeOrigin;
  final bool live;
  const ObdTelemetryChart({
    super.key,
    required this.samples,
    required this.parameter,
    this.timeOrigin,
    this.live = false,
  });

  @override
  State<ObdTelemetryChart> createState() => _ObdTelemetryChartState();
}

class _ObdTelemetryChartState extends State<ObdTelemetryChart> {
  final _transform = TransformationController();
  List<ObdSample>? _pausedSamples;
  DateTime? _pausedOrigin;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final next = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      12.0,
    );
    // Zoom from the start of the visible history. Pinch/drag supports arbitrary
    // focus and horizontal navigation; reset restores the whole loaded window.
    _transform.value = Matrix4.identity()..scaleByDouble(next, next, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final samples = _pausedSamples ?? widget.samples;
    final origin =
        _pausedOrigin ??
        widget.timeOrigin ??
        (samples.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : samples.first.receivedAt);
    final points = <FlSpot>[];
    final timestamps = <DateTime?>[];
    DateTime? previous;
    for (final sample in samples) {
      final gap = previous == null
          ? Duration.zero
          : sample.receivedAt.difference(previous);
      if (gap > const Duration(seconds: 6) || gap.isNegative) {
        points.add(FlSpot.nullSpot);
        timestamps.add(null);
      }
      final valid =
          sample.status == ObdSampleStatus.valid &&
          sample.value != null &&
          sample.value!.isFinite;
      points.add(
        valid
            ? FlSpot(
                sample.receivedAt.difference(origin).inMilliseconds / 1000,
                sample.value!,
              )
            : FlSpot.nullSpot,
      );
      timestamps.add(valid ? sample.receivedAt : null);
      previous = sample.receivedAt;
    }
    final valid = points.where((point) => !point.isNull()).toList();
    final parameter = widget.parameter;
    final unit = switch (parameter) {
      ObdParameter.coolant || ObdParameter.intake => '\u00b0C',
      _ => parameter.unit,
    };
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 11);
    final color = theme.colorScheme.primary;
    final minX = valid.isEmpty ? 0.0 : valid.map((p) => p.x).reduce(math.min);
    final maxX = valid.isEmpty
        ? 1.0
        : math.max(minX + 1, valid.map((p) => p.x).reduce(math.max));
    final minutes = maxX - minX >= 120;
    final minValue = valid.isEmpty
        ? 0.0
        : valid.map((p) => p.y).reduce(math.min);
    final maxValue = valid.isEmpty
        ? 1.0
        : valid.map((p) => p.y).reduce(math.max);
    final padding = math.max(
      (maxValue - minValue) * 0.1,
      math.max(maxValue.abs() * 0.02, 1.0),
    );
    final minY =
        minValue >= 0 &&
            parameter != ObdParameter.shortTrim &&
            parameter != ObdParameter.longTrim
        ? math.max(0.0, minValue - padding)
        : minValue - padding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.live)
              TextButton.icon(
                onPressed: () => setState(() {
                  if (_pausedSamples == null) {
                    _pausedSamples = List.of(widget.samples);
                    _pausedOrigin = origin;
                  } else {
                    _pausedSamples = null;
                    _pausedOrigin = null;
                    _transform.value = Matrix4.identity();
                  }
                }),
                icon: Icon(
                  _pausedSamples == null ? Icons.pause : Icons.play_arrow,
                ),
                label: Text(
                  _pausedSamples == null ? 'Pause graph' : 'Resume graph',
                ),
              ),
            IconButton(
              tooltip: 'Zoom in',
              onPressed: valid.isEmpty ? null : () => _zoom(2),
              icon: const Icon(Icons.zoom_in),
            ),
            IconButton(
              tooltip: 'Zoom out',
              onPressed: valid.isEmpty ? null : () => _zoom(0.5),
              icon: const Icon(Icons.zoom_out),
            ),
            TextButton.icon(
              onPressed: () => _transform.value = Matrix4.identity(),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset view'),
            ),
          ],
        ),
        if (valid.isEmpty)
          const SizedBox(
            height: 180,
            child: Center(
              child: Text('No valid readings in this graph window.'),
            ),
          )
        else
          SizedBox(
            height: 270,
            child: LineChart(
              duration: Duration.zero,
              transformationConfig: FlTransformationConfig(
                scaleAxis: FlScaleAxis.horizontal,
                maxScale: 12,
                transformationController: _transform,
              ),
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxValue + padding,
                clipData: const FlClipData.all(),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(
                      '${parameter.label} ($unit)',
                      style: style,
                    ),
                    axisNameSize: 22,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(
                          math.max(
                            parameter.decimals,
                            _tickDecimals(meta.appliedInterval),
                          ),
                        ),
                        style: style,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(
                      'Elapsed time (${minutes ? 'min' : 's'})',
                      style: style,
                    ),
                    axisNameSize: 22,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) => Text(
                        (minutes ? value / 60 : value).toStringAsFixed(
                          _tickDecimals(
                            minutes
                                ? meta.appliedInterval / 60
                                : meta.appliedInterval,
                          ),
                        ),
                        style: style,
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    color: color,
                    barWidth: 2,
                    isCurved: false,
                    dotData: FlDotData(show: valid.length == 1),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    maxContentWidth: 180,
                    getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final time = timestamps[spot.spotIndex]!.toLocal();
                      final clock =
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${time.millisecond.toString().padLeft(3, '0')}';
                      return LineTooltipItem(
                        '${spot.y.toStringAsFixed(parameter.decimals)} $unit\n${spot.x.toStringAsFixed(2)} s elapsed\n$clock',
                        style.copyWith(
                          color: theme.colorScheme.onInverseSurface,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          _pausedSamples == null
              ? 'Tap or hold a point to inspect. Pinch to zoom; drag when zoomed to move through time.'
              : 'Graph paused. Live readings and recording continue.',
          style: style,
        ),
      ],
    );
  }
}
