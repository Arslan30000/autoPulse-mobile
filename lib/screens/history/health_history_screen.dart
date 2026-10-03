import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/section_header.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';
import 'package:autopulse_ai/navigation/app_router.dart';

class HealthHistoryScreen extends StatelessWidget {
  const HealthHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = MockData.healthHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Health History')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Health Trend'),
            const SizedBox(height: 12),

            // Chart
            Container(
              height: 220,
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
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.surfaceTertiary,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Aug 12', 'Aug 17', 'Aug 20', 'Aug 24'];
                          final idx = value.toInt();
                          if (idx >= 0 && idx < labels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                labels[idx],
                                style: AppTextStyles.labelSmall,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 30,
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
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.primary,
                            strokeWidth: 2,
                            strokeColor: AppColors.background,
                          );
                        },
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

            const SectionHeader(title: 'Recent Events'),
            const SizedBox(height: 12),

            // Events list
            ...history.asMap().entries.map((entry) {
              final event = entry.value;
              final monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
              final dateStr = '${monthNames[event.date.month - 1]} ${event.date.day}';
              final hasTap = event.anomalyId != null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: hasTap
                      ? () => Navigator.pushNamed(
                            context,
                            AppRouter.diagnosticDetail,
                            arguments: MockData.anomalies.first,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Text(dateStr, style: AppTextStyles.labelSmall),
                            const SizedBox(height: 4),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: event.score >= 90
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15),
                              child: Text(
                                '${event.score}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: event.score >= 90 ? AppColors.success : AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(event.description, style: AppTextStyles.bodyMedium),
                        ),
                        if (hasTap)
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
