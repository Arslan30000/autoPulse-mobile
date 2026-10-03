import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';

class MechanicTelemetryScreen extends StatefulWidget {
  const MechanicTelemetryScreen({super.key});

  @override
  State<MechanicTelemetryScreen> createState() =>
      _MechanicTelemetryScreenState();
}

class _MechanicTelemetryScreenState extends State<MechanicTelemetryScreen> {
  final Random _random = Random();
  Timer? _timer;
  final double _speed = 0;
  double _rpm = 780,
      _coolant = 69,
      _intake = 63,
      _load = 12,
      _throttle = 18.04,
      _maf = 0.21;
  final List<double> _mafHistory = [
    0.35,
    0.33,
    0.30,
    0.28,
    0.25,
    0.23,
    0.22,
    0.21,
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() {
        _rpm = 780 + (_random.nextDouble() * 60 - 30);
        _coolant = 69 + (_random.nextDouble() * 2 - 1);
        _intake = 63 + (_random.nextDouble() * 2 - 1);
        _load = 12 + (_random.nextDouble() * 3 - 1.5);
        _throttle = 18.04 + (_random.nextDouble() * 2 - 1);
        _maf = 0.21 + (_random.nextDouble() * 0.04 - 0.02);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Telemetry Dashboard')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connected bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      MockData.vehicle.fullDisplayName,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Engine section
              _buildSection('Engine Parameters', [
                _TelemetryRow(
                  'Engine RPM',
                  _rpm.toStringAsFixed(0),
                  'rpm',
                  '650-900',
                  _isInRange(_rpm, 650, 900),
                ),
                _TelemetryRow(
                  'Engine Load',
                  _load.toStringAsFixed(1),
                  '%',
                  '10-20',
                  _isInRange(_load, 10, 20),
                ),
              ]),

              const SizedBox(height: 16),

              // Air Intake section
              _buildSection('Air Intake', [
                _TelemetryRow(
                  'MAF',
                  _maf.toStringAsFixed(2),
                  'g/s',
                  '2.5-4.0',
                  false,
                ),
                _TelemetryRow(
                  'Intake Temp',
                  _intake.toStringAsFixed(0),
                  '°C',
                  '20-70',
                  _isInRange(_intake, 20, 70),
                ),
              ]),

              const SizedBox(height: 16),

              // MAF Chart
              Container(
                height: 180,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MAF Trend', style: AppTextStyles.titleSmall),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: AppColors.surfaceTertiary,
                              strokeWidth: 0.5,
                            ),
                          ),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          minY: 0,
                          maxY: 0.5,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _mafHistory
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                                  .toList(),
                              isCurved: true,
                              color: AppColors.warning,
                              barWidth: 2,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (_, _, _, _) =>
                                    FlDotCirclePainter(
                                      radius: 2.5,
                                      color: AppColors.warning,
                                      strokeWidth: 0,
                                    ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.warning.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                          ],
                          lineTouchData: const LineTouchData(enabled: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Cooling section
              _buildSection('Cooling System', [
                _TelemetryRow(
                  'Coolant Temp',
                  _coolant.toStringAsFixed(0),
                  '°C',
                  '60-100',
                  _isInRange(_coolant, 60, 100),
                ),
              ]),

              const SizedBox(height: 16),

              // Throttle section
              _buildSection('Throttle & Speed', [
                _TelemetryRow(
                  'Throttle Position',
                  _throttle.toStringAsFixed(2),
                  '%',
                  '0-100',
                  true,
                ),
                _TelemetryRow(
                  'Vehicle Speed',
                  _speed.toStringAsFixed(0),
                  'km/h',
                  '0-180',
                  true,
                ),
              ]),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  bool _isInRange(double value, double min, double max) =>
      value >= min && value <= max;

  Widget _buildSection(String title, List<_TelemetryRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [Text(title, style: AppTextStyles.titleSmall)],
            ),
          ),
          const Divider(height: 1),
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Parameter', style: AppTextStyles.labelSmall),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Current',
                    style: AppTextStyles.labelSmall,
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Baseline',
                    style: AppTextStyles.labelSmall,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(
                  width: 40,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.name,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${row.value} ${row.unit}',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: row.inRange
                            ? AppColors.textPrimary
                            : AppColors.warning,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.baseline,
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Icon(
                      row.inRange
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: row.inRange
                          ? AppColors.success
                          : AppColors.warning,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TelemetryRow {
  final String name, value, unit, baseline;
  final bool inRange;
  _TelemetryRow(this.name, this.value, this.unit, this.baseline, this.inRange);
}
