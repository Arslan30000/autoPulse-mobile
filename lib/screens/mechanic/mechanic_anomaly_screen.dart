import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/section_header.dart';
import 'package:autopulse_ai/core/widgets/primary_button.dart';
import 'package:autopulse_ai/navigation/app_router.dart';

class MechanicAnomalyScreen extends StatelessWidget {
  const MechanicAnomalyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Anomaly Analysis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.track_changes_rounded,
                        color: AppColors.warning,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Airflow Deviation',
                          style: AppTextStyles.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip('Confidence', '82%', AppColors.warning),
                      const SizedBox(width: 12),
                      _buildInfoChip('Severity', 'Moderate', AppColors.warning),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        'Detected',
                        '12:28 PM',
                        AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // Parameters involved
            const SectionHeader(title: 'Parameters Involved'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['MAF', 'Engine Load', 'Throttle Position', 'RPM'].map((
                p,
              ) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    p,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

            const SizedBox(height: 24),

            // Expected vs Observed chart
            const SectionHeader(title: 'Expected vs Observed'),
            const SizedBox(height: 12),
            Container(
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Expected',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Observed',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        maxY: 0.6,
                        lineBarsData: [
                          // Expected (baseline)
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 0.38),
                              FlSpot(1, 0.37),
                              FlSpot(2, 0.36),
                              FlSpot(3, 0.37),
                              FlSpot(4, 0.38),
                              FlSpot(5, 0.37),
                              FlSpot(6, 0.36),
                              FlSpot(7, 0.37),
                            ],
                            isCurved: true,
                            color: AppColors.success,
                            barWidth: 2,
                            dashArray: [5, 4],
                            dotData: const FlDotData(show: false),
                          ),
                          // Observed
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 0.35),
                              FlSpot(1, 0.33),
                              FlSpot(2, 0.30),
                              FlSpot(3, 0.28),
                              FlSpot(4, 0.25),
                              FlSpot(5, 0.23),
                              FlSpot(6, 0.22),
                              FlSpot(7, 0.21),
                            ],
                            isCurved: true,
                            color: AppColors.warning,
                            barWidth: 2.5,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                                radius: 2.5,
                                color: AppColors.warning,
                                strokeWidth: 0,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.warning.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                        lineTouchData: const LineTouchData(enabled: false),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

            const SizedBox(height: 24),

            // Why flagged
            const SectionHeader(title: 'Why Was This Flagged?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'The system detected a sustained deviation in airflow-related telemetry from the vehicle\'s learned historical baseline under comparable operating conditions. The MAF reading has decreased from an expected ~0.37 g/s to 0.21 g/s, accompanied by DTC P0101.',
                style: AppTextStyles.bodyMedium,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

            const SizedBox(height: 24),

            // Evidence table
            const SectionHeader(title: 'Supporting Evidence'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildEvidenceRow(
                    'MAF Reading',
                    '0.21 g/s',
                    'Baseline: 2.5-4.0 g/s',
                    false,
                  ),
                  const Divider(height: 1),
                  _buildEvidenceRow(
                    'Engine Load',
                    '12%',
                    'Baseline: 10-20%',
                    true,
                  ),
                  const Divider(height: 1),
                  _buildEvidenceRow('Throttle', '18.04%', 'Normal range', true),
                  const Divider(height: 1),
                  _buildEvidenceRow('DTC', 'P0101', 'Active', false),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

            const SizedBox(height: 32),

            PrimaryButton(
              label: 'AI Diagnostic Analysis',
              icon: Icons.auto_awesome_rounded,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRouter.mechanicAI),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.titleSmall.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceRow(
    String param,
    String value,
    String note,
    bool normal,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              param,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: AppTextStyles.titleSmall.copyWith(
                color: normal ? AppColors.textPrimary : AppColors.warning,
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(note, style: AppTextStyles.labelSmall)),
          Icon(
            normal ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 16,
            color: normal ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }
}
