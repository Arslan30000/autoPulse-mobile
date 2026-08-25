import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/diagnostic_card.dart';
import 'package:autosense_ai/core/widgets/section_header.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';
import 'package:autosense_ai/navigation/app_router.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Diagnostics', style: AppTextStyles.headlineMedium)
                  .animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 4),
              Text(MockData.vehicle.fullDisplayName, style: AppTextStyles.bodyMedium)
                  .animate().fadeIn(duration: 500.ms, delay: 100.ms),

              const SizedBox(height: 24),

              // Summary cards
              Row(
                children: [
                  _buildSummaryCard('1', 'Active\nAnomalies', AppColors.warning),
                  const SizedBox(width: 12),
                  _buildSummaryCard('0', 'Critical\nIssues', AppColors.success),
                  const SizedBox(width: 12),
                  _buildSummaryCard('1', 'Diagnostic\nCodes', AppColors.primary),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 24),

              SectionHeader(title: 'Active Anomalies')
                  .animate().fadeIn(duration: 400.ms, delay: 300.ms),
              const SizedBox(height: 12),

              DiagnosticCard(
                title: MockData.anomalies.first.title,
                severity: MockData.anomalies.first.severity,
                description: MockData.anomalies.first.description,
                status: MockData.anomalies.first.status,
                actionLabel: 'Analyze',
                onAction: () => Navigator.pushNamed(
                  context,
                  AppRouter.diagnosticDetail,
                  arguments: MockData.anomalies.first,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

              const SizedBox(height: 24),

              SectionHeader(title: 'Diagnostic Trouble Codes')
                  .animate().fadeIn(duration: 400.ms, delay: 500.ms),
              const SizedBox(height: 12),

              // DTC Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTertiary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            MockData.dtcs.first.code,
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(MockData.dtcs.first.description, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          MockData.dtcs.first.status,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRouter.diagnosticDetail,
                          arguments: MockData.anomalies.first,
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

              const SizedBox(height: 24),

              // Disclaimer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.textTertiary, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AutoSense provides diagnostic assistance and does not replace professional inspection.',
                        style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 700.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String count, String label, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: AppTextStyles.titleLarge.copyWith(color: accentColor),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}