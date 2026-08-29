import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/section_header.dart';
import 'package:autosense_ai/core/widgets/primary_button.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';
import 'package:autosense_ai/navigation/app_router.dart';

class MechanicDtcScreen extends StatelessWidget {
  const MechanicDtcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Diagnostic Trouble Codes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DTC Header card
            Container(
              padding: const EdgeInsets.all(20),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('P0101', style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary, letterSpacing: 1)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mass or Volume Air Flow', style: AppTextStyles.titleSmall),
                            Text('Circuit Range/Performance', style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip('Severity', 'Moderate', AppColors.warning),
                      _buildChip('Status', 'Needs Investigation', AppColors.warning),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // Code Details
            const SectionHeader(title: 'Code Details'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Text(
                'This code is set when the PCM detects that the MAF sensor signal is outside the expected range for the current engine operating conditions. The ECU compares actual airflow readings against predicted values based on RPM, throttle position, and other parameters.',
                style: AppTextStyles.bodyMedium,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

            const SizedBox(height: 24),

            // Observed Evidence
            const SectionHeader(title: 'Observed Evidence'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  _buildRow('MAF Reading', '0.21 g/s', AppColors.warning),
                  const Divider(height: 1),
                  _buildRow('Expected Range', '2.5 - 4.0 g/s', AppColors.textSecondary),
                  const Divider(height: 1),
                  _buildRow('Engine Load', '12%', AppColors.textPrimary),
                  const Divider(height: 1),
                  _buildRow('Throttle Position', '18.04%', AppColors.textPrimary),
                  const Divider(height: 1),
                  _buildRow('Engine RPM', '780 rpm', AppColors.textPrimary),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

            const SizedBox(height: 24),

            // Possible causes
            const SectionHeader(title: 'Possible Causes'),
            const SizedBox(height: 8),
            ..._buildNumberedList([
              'Dirty or contaminated MAF sensor',
              'Air leak in intake system (post-MAF)',
              'Faulty MAF sensor or wiring',
              'Restricted air filter',
              'Vacuum leak',
            ], AppColors.warning),

            const SizedBox(height: 24),

            // Recommended tests
            const SectionHeader(title: 'Recommended Tests'),
            const SizedBox(height: 8),
            ..._buildNumberedList([
              'Visual inspection of air intake path',
              'MAF sensor cleaning or replacement test',
              'Compare MAF readings at idle and under load',
              'Smoke test for intake leaks',
              'Check for stored freeze frame data',
            ], AppColors.primary),

            const SizedBox(height: 32),

            PrimaryButton(
              label: 'AI Analysis',
              icon: Icons.auto_awesome_rounded,
              onPressed: () => Navigator.pushNamed(context, AppRouter.mechanicAI),
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
          Text(value, style: AppTextStyles.titleSmall.copyWith(color: valueColor)),
        ],
      ),
    );
  }

  List<Widget> _buildNumberedList(List<String> items, Color color) {
    return items.asMap().entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.surfaceTertiary,
              child: Text('${entry.key + 1}', style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(entry.value, style: AppTextStyles.bodyMedium)),
          ],
        ),
      );
    }).toList();
  }
}
