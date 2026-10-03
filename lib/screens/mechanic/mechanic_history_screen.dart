import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/section_header.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';
import 'package:autopulse_ai/navigation/app_router.dart';

class MechanicHistoryScreen extends StatelessWidget {
  const MechanicHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vehicle History')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    MockData.vehicle.fullDisplayName,
                    style: AppTextStyles.titleSmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Health Score Trend
            const SectionHeader(title: 'Health Score Trend'),
            const SizedBox(height: 12),
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
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.surfaceTertiary,
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, _) {
                          const labels = [
                            'Aug 12',
                            'Aug 17',
                            'Aug 20',
                            'Aug 24',
                          ];
                          final i = value.toInt();
                          return i >= 0 && i < labels.length
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    labels[i],
                                    style: AppTextStyles.labelSmall,
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 80,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 93),
                        FlSpot(1, 94),
                        FlSpot(2, 91),
                        FlSpot(3, 87),
                      ],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: AppColors.background,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: const LineTouchData(enabled: false),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms),

            const SizedBox(height: 24),

            // Diagnostic Sessions
            const SectionHeader(title: 'Diagnostic Sessions'),
            const SizedBox(height: 12),
            _buildSessionCard(
              'Aug 24, 2025',
              '12:28 PM',
              87,
              1,
              1,
              true,
              context,
            ),
            _buildSessionCard(
              'Aug 20, 2025',
              '09:45 AM',
              91,
              0,
              0,
              false,
              context,
            ),
            _buildSessionCard(
              'Aug 17, 2025',
              '14:30 PM',
              94,
              0,
              0,
              false,
              context,
            ),
            _buildSessionCard(
              'Aug 12, 2025',
              '10:15 AM',
              93,
              0,
              0,
              false,
              context,
            ),

            const SizedBox(height: 24),

            // DTC History
            const SectionHeader(title: 'DTC History'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildDtcHistoryRow(
                    'P0101',
                    'Aug 24',
                    'Active',
                    AppColors.warning,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

            const SizedBox(height: 24),

            // Anomaly History
            const SectionHeader(title: 'Anomaly History'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildAnomalyHistoryRow(
                    'Airflow Deviation',
                    'Aug 24',
                    '82%',
                    AppColors.warning,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    String date,
    String time,
    int health,
    int dtcs,
    int anomalies,
    bool hasIssues,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: hasIssues
            ? () => Navigator.pushNamed(context, AppRouter.mechanicAnomaly)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: AppTextStyles.titleSmall),
                  Text(time, style: AppTextStyles.labelSmall),
                ],
              ),
              const Spacer(),
              _buildMiniStat(
                'Health',
                '$health',
                health >= 90 ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 12),
              _buildMiniStat(
                'DTCs',
                '$dtcs',
                dtcs > 0 ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(width: 12),
              _buildMiniStat(
                'Anomalies',
                '$anomalies',
                anomalies > 0 ? AppColors.warning : AppColors.success,
              ),
              if (hasIssues) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.titleSmall.copyWith(color: color)),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildDtcHistoryRow(
    String code,
    String date,
    String status,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(date, style: AppTextStyles.bodySmall),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyHistoryRow(
    String name,
    String date,
    String confidence,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.track_changes_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(date, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              confidence,
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
