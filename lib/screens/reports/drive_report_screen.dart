import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/health_score_widget.dart';
import 'package:autopulse_ai/core/widgets/section_header.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';

class DriveReportScreen extends StatelessWidget {
  const DriveReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final report = MockData.driveReport;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Drive Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Vehicle info
            Center(
              child: Text(
                MockData.vehicle.fullDisplayName,
                style: AppTextStyles.titleMedium,
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // Health score
            Center(
              child: HealthScoreWidget(
                score: report.healthScore,
                status: 'Good',
                size: 140,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 100.ms),

            const SizedBox(height: 24),

            // Statistics grid
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard('Distance', '${report.distance} km', null),
                _buildStatCard('Avg Speed', '${report.avgSpeed.toStringAsFixed(0)} km/h', null),
                _buildStatCard('Anomalies', '${report.anomalyCount}', AppColors.warning),
                _buildStatCard('DTCs', '${report.dtcCount}', AppColors.warning),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: const SectionHeader(title: 'Summary'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(report.summary, style: AppTextStyles.bodyMedium),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: const SectionHeader(title: 'System Status'),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: report.systemStatuses.entries.map((entry) {
                  final isNormal = entry.value == 'Normal';
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(entry.key, style: AppTextStyles.bodyMedium),
                            ),
                            Icon(
                              isNormal ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              color: isNormal ? AppColors.success : AppColors.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.value,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isNormal ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (entry.key != report.systemStatuses.keys.last)
                        const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Detailed Report'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Report'),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color? valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
