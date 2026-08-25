import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/telemetry_card.dart';
import 'package:autosense_ai/core/widgets/section_header.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  final Random _random = Random();
  Timer? _timer;
  
  double _rpm = 780;
  double _speed = 0;
  double _coolantTemp = 69;
  double _intakeTemp = 63;
  double _engineLoad = 12;
  double _throttle = 18.04;
  double _maf = 0.21;
  
  final List<double> _rpmHistory = [];
  
  @override
  void initState() {
    super.initState();
    _rpmHistory.add(_rpm);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() {
        _rpm = 780 + (_random.nextDouble() * 60 - 30);
        _coolantTemp = 69 + (_random.nextDouble() * 2 - 1);
        _intakeTemp = 63 + (_random.nextDouble() * 2 - 1);
        _engineLoad = 12 + (_random.nextDouble() * 3 - 1.5);
        _throttle = 18.04 + (_random.nextDouble() * 2 - 1);
        _maf = 0.21 + (_random.nextDouble() * 0.04 - 0.02);
        
        _rpmHistory.add(_rpm);
        if (_rpmHistory.length > 20) {
          _rpmHistory.removeAt(0);
        }
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
      appBar: AppBar(
        title: const Text('Live Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connected status bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      'Connected',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
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
              const SectionHeader(title: 'Live Data'),
              const SizedBox(height: 12),

              // Telemetry grid
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  TelemetryCard(
                    label: 'Engine RPM',
                    value: _rpm.toStringAsFixed(0),
                    unit: 'rpm',
                    icon: Icons.speed_rounded,
                  ),
                  TelemetryCard(
                    label: 'Vehicle Speed',
                    value: _speed.toStringAsFixed(0),
                    unit: 'km/h',
                    icon: Icons.directions_car_rounded,
                  ),
                  TelemetryCard(
                    label: 'Coolant Temp',
                    value: _coolantTemp.toStringAsFixed(0),
                    unit: '°C',
                    icon: Icons.thermostat_rounded,
                  ),
                  TelemetryCard(
                    label: 'Intake Air Temp',
                    value: _intakeTemp.toStringAsFixed(0),
                    unit: '°C',
                    icon: Icons.air_rounded,
                    statusColor: AppColors.warning,
                  ),
                  TelemetryCard(
                    label: 'Engine Load',
                    value: _engineLoad.toStringAsFixed(0),
                    unit: '%',
                    icon: Icons.data_usage_rounded,
                  ),
                  TelemetryCard(
                    label: 'Throttle Position',
                    value: _throttle.toStringAsFixed(2),
                    unit: '%',
                    icon: Icons.tune_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // MAF full width
              TelemetryCard(
                label: 'Mass Air Flow',
                value: _maf.toStringAsFixed(2),
                unit: 'g/s',
                icon: Icons.waves_rounded,
                statusColor: AppColors.warning,
              ),

              const SizedBox(height: 20),
              const SectionHeader(title: 'Engine RPM'),
              const SizedBox(height: 12),

              // RPM Chart
              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: AppColors.surfaceTertiary,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: 720,
                    maxY: 840,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _rpmHistory.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value);
                        }).toList(),
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 3,
                              color: AppColors.primary,
                              strokeWidth: 0,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                    ],
                    lineTouchData: const LineTouchData(enabled: false),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.fiber_manual_record, size: 12),
                      label: const Text('Record Drive'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _rpmHistory.clear();
                          _rpmHistory.add(_rpm);
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}