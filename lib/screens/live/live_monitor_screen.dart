import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1500.ms),
                      const SizedBox(width: 12),
                      Text(
                        'CONNECTED',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 1,
                        height: 16,
                        color: Colors.white24,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        MockData.vehicle.fullDisplayName,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: -0.2),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Live Data').animate().fade(duration: 500.ms).slideX(begin: -0.2),
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
                  ).animate().fade(duration: 600.ms, delay: 100.ms).scale(begin: const Offset(0.9, 0.9)),
                  TelemetryCard(
                    label: 'Vehicle Speed',
                    value: _speed.toStringAsFixed(0),
                    unit: 'km/h',
                    icon: Icons.directions_car_rounded,
                  ).animate().fade(duration: 600.ms, delay: 150.ms).scale(begin: const Offset(0.9, 0.9)),
                  TelemetryCard(
                    label: 'Coolant Temp',
                    value: _coolantTemp.toStringAsFixed(0),
                    unit: '°C',
                    icon: Icons.thermostat_rounded,
                  ).animate().fade(duration: 600.ms, delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
                  TelemetryCard(
                    label: 'Intake Air Temp',
                    value: _intakeTemp.toStringAsFixed(0),
                    unit: '°C',
                    icon: Icons.air_rounded,
                    statusColor: AppColors.warning,
                  ).animate().fade(duration: 600.ms, delay: 250.ms).scale(begin: const Offset(0.9, 0.9)),
                  TelemetryCard(
                    label: 'Engine Load',
                    value: _engineLoad.toStringAsFixed(0),
                    unit: '%',
                    icon: Icons.data_usage_rounded,
                  ).animate().fade(duration: 600.ms, delay: 300.ms).scale(begin: const Offset(0.9, 0.9)),
                  TelemetryCard(
                    label: 'Throttle Position',
                    value: _throttle.toStringAsFixed(2),
                    unit: '%',
                    icon: Icons.tune_rounded,
                  ).animate().fade(duration: 600.ms, delay: 350.ms).scale(begin: const Offset(0.9, 0.9)),
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
              ).animate().fade(duration: 600.ms, delay: 400.ms).scale(begin: const Offset(0.9, 0.9)),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Engine RPM Dynamics').animate().fade(duration: 500.ms, delay: 300.ms).slideX(begin: -0.2),
              const SizedBox(height: 16),

              // RPM Chart
              Container(
                height: 220,
                padding: const EdgeInsets.only(top: 24, right: 24, left: 16, bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF121418), // Deep tech background
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      drawHorizontalLine: true,
                      horizontalInterval: 30,
                      verticalInterval: 5,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.white.withValues(alpha: 0.05),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.white.withValues(alpha: 0.05),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: AppTextStyles.labelSmall.copyWith(color: Colors.white38),
                            );
                          },
                        ),
                      ),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 700,
                    maxY: 850,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _rpmHistory.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value);
                        }).toList(),
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Colors.purpleAccent],
                        ),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: index == _rpmHistory.length - 1 ? 4 : 0,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: Colors.purpleAccent,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.2),
                              Colors.purpleAccent.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(0)} RPM',
                              AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ).animate().fade(duration: 700.ms, delay: 500.ms).slideY(begin: 0.1),

              const SizedBox(height: 32),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {},
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 16)
                                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                                  .fade(duration: 800.ms, begin: 0.5, end: 1.0),
                              const SizedBox(width: 8),
                              Text(
                                'REC DRIVE',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Colors.blueAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _rpmHistory.clear();
                              _rpmHistory.add(_rpm);
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'REFRESH',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fade(duration: 800.ms, delay: 600.ms).slideY(begin: 0.2),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
