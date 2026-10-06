import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Labels the existing demonstration charts without implying actual trip times.
FlTitlesData demoChartTitles({bool health = false}) => FlTitlesData(
  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  leftTitles: AxisTitles(
    axisNameWidget: Text(health ? 'Health score (/100)' : 'MAF (g/s)'),
    axisNameSize: 22,
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 38,
      interval: health ? 5 : 0.1,
      getTitlesWidget: (value, _) => Text(
        value.toStringAsFixed(health ? 0 : 1),
        style: const TextStyle(fontSize: 10),
      ),
    ),
  ),
  bottomTitles: AxisTitles(
    axisNameWidget: Text(health ? 'Date (demo)' : 'Sample index (demo)'),
    axisNameSize: 22,
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 24,
      interval: health ? 1 : 2,
      getTitlesWidget: (value, _) {
        const dates = ['Aug 12', 'Aug 17', 'Aug 20', 'Aug 24'];
        if (health &&
            (value != value.roundToDouble() ||
                value < 0 ||
                value >= dates.length)) {
          return const SizedBox.shrink();
        }
        return Text(
          health ? dates[value.toInt()] : value.toStringAsFixed(0),
          style: const TextStyle(fontSize: 10),
        );
      },
    ),
  ),
);

LineTouchData demoChartTouches({
  bool health = false,
  bool comparison = false,
}) => LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipItems: (spots) => spots.map((spot) {
      const dates = ['Aug 12', 'Aug 17', 'Aug 20', 'Aug 24'];
      final index = spot.x.round();
      final x = health && index >= 0 && index < dates.length
          ? dates[index]
          : 'Sample $index';
      final name = comparison
          ? (spot.barIndex == 0 ? 'Expected' : 'Observed')
          : (health ? 'Health score' : 'MAF');
      return LineTooltipItem(
        '$name: ${spot.y.toStringAsFixed(health ? 0 : 2)} ${health ? '/100' : 'g/s'}\n$x (demo)',
        const TextStyle(color: Colors.white, fontSize: 12),
      );
    }).toList(),
  ),
);
