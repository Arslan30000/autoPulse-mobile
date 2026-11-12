import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/telemetry_plot.dart';

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
  final double height;
  const ObdTelemetryChart({
    super.key,
    required this.samples,
    required this.parameter,
    this.timeOrigin,
    this.live = false,
    this.height = 270,
  });

  @override
  State<ObdTelemetryChart> createState() => _ObdTelemetryChartState();
}

class _ObdTelemetryChartState extends State<ObdTelemetryChart> {
  final _transform = TransformationController();
  List<ObdSample>? _pausedSamples;
  DateTime? _pausedOrigin;
  List<ObdSample>? _sourceSamples;
  TelemetrySeries? _series;
  double _plotWidth = 1;
  double get _maxScale => widget.live ? 12 : 1024;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_viewChanged);
  }

  void _viewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ObdTelemetryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parameter != widget.parameter ||
        oldWidget.timeOrigin != widget.timeOrigin ||
        oldWidget.live != widget.live ||
        (oldWidget.samples.isNotEmpty && widget.samples.isEmpty)) {
      _pausedSamples = null;
      _pausedOrigin = null;
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transform.removeListener(_viewChanged);
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final scale = _transform.value.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(1.0, _maxScale);
    final center = (_plotWidth / 2 - _transform.value.storage[12]) / scale;
    final translation = (_plotWidth / 2 - center * next).clamp(
      -_plotWidth * (next - 1),
      0.0,
    );
    _transform.value = Matrix4.identity()
      ..translateByDouble(translation, 0, 0, 1)
      ..scaleByDouble(next, next, 1, 1);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildChart(context, constraints.maxWidth),
  );

  Widget _buildChart(BuildContext context, double width) {
    final samples = _pausedSamples ?? widget.samples;
    final origin =
        _pausedOrigin ??
        widget.timeOrigin ??
        (samples.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : samples.first.receivedAt);
    if (!identical(_sourceSamples, samples) || _series?.origin != origin) {
      _sourceSamples = samples;
      _series = TelemetrySeries(samples, origin);
    }
    final series = _series!;
    final hasValues = series.validCount > 0;
    final minX = series.minX;
    final maxX = series.maxX;
    // The left axis reserves 48 pixels for tick labels and 22 for its name.
    _plotWidth = math.max(1, width - 70);
    final scale = _transform.value.getMaxScaleOnAxis();
    final translation = _transform.value.storage[12];
    final from = minX + (-translation / (scale * _plotWidth)) * (maxX - minX);
    final to = from + (maxX - minX) / scale;
    final view = series.viewport(from, to);
    final points = <FlSpot>[];
    final timestamps = <DateTime?>[];
    final isolated = <FlSpot>{};
    for (final segment in view.segments) {
      if (points.isNotEmpty) {
        points.add(FlSpot.nullSpot);
        timestamps.add(null);
      }
      for (final sample in segment) {
        final point = FlSpot(series.seconds(sample), sample.value!);
        points.add(point);
        timestamps.add(sample.receivedAt);
        if (segment.length == 1) isolated.add(point);
      }
    }
    final parameter = widget.parameter;
    final unit = switch (parameter) {
      ObdParameter.coolant || ObdParameter.intake => '\u00b0C',
      _ => parameter.unit,
    };
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 11);
    final color = theme.colorScheme.primary;
    final minutes = maxX - minX >= 120;
    final minValue = hasValues ? series.minValue : 0.0;
    final maxValue = hasValues ? series.maxValue : 1.0;
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
              onPressed: hasValues ? () => _zoom(2) : null,
              icon: const Icon(Icons.zoom_in),
            ),
            IconButton(
              tooltip: 'Zoom out',
              onPressed: hasValues ? () => _zoom(0.5) : null,
              icon: const Icon(Icons.zoom_out),
            ),
            TextButton.icon(
              onPressed: () => _transform.value = Matrix4.identity(),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset view'),
            ),
          ],
        ),
        if (!hasValues)
          const SizedBox(
            height: 180,
            child: Center(
              child: Text('No valid readings in this graph window.'),
            ),
          )
        else
          SizedBox(
            height: widget.height,
            child: LineChart(
              duration: Duration.zero,
              transformationConfig: FlTransformationConfig(
                scaleAxis: FlScaleAxis.horizontal,
                maxScale: _maxScale,
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
                      minIncluded: false,
                      maxIncluded: false,
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
                      minIncluded: false,
                      maxIncluded: false,
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
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, _) => isolated.contains(spot),
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 2.5,
                        color: color,
                        strokeWidth: 0,
                      ),
                    ),
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
        if (!widget.live && hasValues) ...[
          Text(
            '${view.visibleCount} valid readings in view · ${view.plottedCount} plot points. Zoom in to inspect individual readings.',
            style: style,
          ),
          Text(
            '${series.validCount} valid · ${series.missingCount} missing/invalid · ${series.timeGapCount} recorded gaps over 6 s${series.clockResetCount > 0 ? ' · ${series.clockResetCount} clock resets' : ''}',
            style: style,
          ),
          const SizedBox(height: 8),
        ],
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
