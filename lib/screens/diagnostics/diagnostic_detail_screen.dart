import 'package:autopulse_ai/core/widgets/chart_labels.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/primary_button.dart';
import 'package:autopulse_ai/core/widgets/section_header.dart';
import 'package:autopulse_ai/models/diagnostic.dart';
import 'package:autopulse_ai/navigation/app_router.dart';

class DiagnosticDetailScreen extends StatelessWidget {
  final Anomaly anomaly;

  const DiagnosticDetailScreen({super.key, required this.anomaly});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(anomaly.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity + time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    anomaly.severity,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
                const Spacer(),
                Text('Today \u2022 12:28 PM', style: AppTextStyles.bodySmall),
              ],
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 20),

            // Chart
            Container(
              height: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MAF Sensor Readings', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LineChart(
                      transformationConfig: const FlTransformationConfig(
                        scaleAxis: FlScaleAxis.horizontal,
                        maxScale: 8,
                      ),
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 0.1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: AppColors.surfaceTertiary,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: demoChartTitles(),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                        maxY: 0.5,
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 0.35),
                              FlSpot(1, 0.33),
                              FlSpot(2, 0.30),
                              FlSpot(3, 0.28),
                              FlSpot(4, 0.25),
                              FlSpot(5, 0.24),
                              FlSpot(6, 0.22),
                              FlSpot(7, 0.21),
                              FlSpot(8, 0.21),
                            ],
                            isCurved: true,
                            color: AppColors.warning,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 3,
                                  color: AppColors.warning,
                                  strokeWidth: 0,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.warning.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                        lineTouchData: demoChartTouches(),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

            const SizedBox(height: 24),

            const SectionHeader(title: 'What We Detected'),
            const SizedBox(height: 8),
            Text(
              anomaly.detailedDescription,
              style: AppTextStyles.bodyMedium,
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

            const SizedBox(height: 24),

            const SectionHeader(title: 'Possible Contributing Factors'),
            const SizedBox(height: 8),
            Column(
              children: anomaly.contributingFactors.map((factor) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_right_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(factor, style: AppTextStyles.bodyMedium),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

            const SizedBox(height: 24),

            const SectionHeader(title: 'Recommended Checks'),
            const SizedBox(height: 8),
            Column(
              children: anomaly.recommendedChecks.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.surfaceTertiary,
                        child: Text(
                          '${entry.key + 1}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

            const SizedBox(height: 32),

            PrimaryButton(
              label: 'Ask autopulse AI',
              icon: Icons.auto_awesome_rounded,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRouter.aiAssistant),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
