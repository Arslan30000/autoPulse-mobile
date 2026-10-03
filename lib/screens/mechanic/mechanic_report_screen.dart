import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/health_score_widget.dart';
import 'package:autopulse_ai/core/widgets/section_header.dart';
import 'package:autopulse_ai/core/widgets/primary_button.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';

class MechanicReportScreen extends StatelessWidget {
  const MechanicReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Diagnostic Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.sensors_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text('autopulse', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
                      const Spacer(),
                      Text('Diagnostic Report', style: AppTextStyles.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Vehicle', style: AppTextStyles.labelSmall),
                        Text(MockData.vehicle.fullDisplayName, style: AppTextStyles.titleSmall),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Date', style: AppTextStyles.labelSmall),
                        Text('25 Aug 2026', style: AppTextStyles.titleSmall),
                      ]),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // Summary stats
            Row(
              children: [
                _buildStatCard('Health', '87/100', AppColors.success),
                const SizedBox(width: 10),
                _buildStatCard('DTCs', '1', AppColors.warning),
                const SizedBox(width: 10),
                _buildStatCard('Anomalies', '1', AppColors.warning),
                const SizedBox(width: 10),
                _buildStatCard('Critical', '0', AppColors.success),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

            const SizedBox(height: 24),

            // Observed Issues
            const SectionHeader(title: 'Observed Issues'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Text('Airflow Deviation', style: AppTextStyles.titleSmall),
                      const Spacer(),
                      Text('Moderate', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('MAF sensor reading (0.21 g/s) deviates significantly from learned baseline (2.5-4.0 g/s). Associated DTC P0101 active.', style: AppTextStyles.bodySmall),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

            const SizedBox(height: 24),

            // Evidence
            const SectionHeader(title: 'Evidence'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  _buildEvidenceRow('MAF Reading', '0.21 g/s', false),
                  const Divider(height: 1),
                  _buildEvidenceRow('Baseline MAF', '2.5-4.0 g/s', true),
                  const Divider(height: 1),
                  _buildEvidenceRow('DTC', 'P0101 Active', false),
                  const Divider(height: 1),
                  _buildEvidenceRow('Engine Load', '12% (Normal)', true),
                  const Divider(height: 1),
                  _buildEvidenceRow('Coolant Temp', '69°C (Normal)', true),
                  const Divider(height: 1),
                  _buildEvidenceRow('Anomaly Confidence', '82%', false),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

            const SizedBox(height: 24),

            // AI Analysis
            const SectionHeader(title: 'AI Analysis'),
            const SizedBox(height: 8),
            Text(
              'The airflow anomaly indicates a potential MAF sensor issue or intake restriction. The progressive decline in MAF readings over recent sessions suggests a developing condition rather than an intermittent fault. Early intervention is recommended to prevent further system degradation.',
              style: AppTextStyles.bodyMedium,
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

            const SizedBox(height: 24),

            // Recommended Inspection
            const SectionHeader(title: 'Recommended Inspection'),
            const SizedBox(height: 8),
            ...[
              'Inspect and clean MAF sensor with approved solvent (do not touch sensor element)',
              'Verify all intake system connections and seals for air leaks',
              'Perform intake smoke test if suspected restriction',
              'Compare live MAF readings during various load conditions',
              'Clear code P0101 and monitor for reoccurrence',
              'Consider professional diagnostic if issue persists after cleaning',
            ].asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 11, backgroundColor: AppColors.surfaceTertiary, child: Text('${e.key + 1}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.value, style: AppTextStyles.bodyMedium)),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.textTertiary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('autopulse provides diagnostic assistance and does not replace professional vehicle inspection.', style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic))),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.picture_as_pdf_rounded, size: 18), label: const Text('Generate Report'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.share_rounded, size: 18), label: const Text('Share Report'))),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.titleSmall.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceRow(String label, String value, bool normal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary))),
          Text(value, style: AppTextStyles.titleSmall.copyWith(color: normal ? AppColors.textPrimary : AppColors.warning)),
        ],
      ),
    );
  }
}