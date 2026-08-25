import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/connection_indicator.dart';
import 'package:autosense_ai/core/widgets/section_header.dart';
import 'package:autosense_ai/core/widgets/telemetry_card.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';
import 'package:autosense_ai/navigation/app_router.dart';

class MechanicHomeScreen extends StatelessWidget {
  const MechanicHomeScreen({super.key});

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
              // Header
              Text('Diagnostic Center', style: AppTextStyles.headlineMedium)
                  .animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(MockData.vehicle.fullDisplayName, style: AppTextStyles.bodyMedium),
                  const Spacer(),
                  const ConnectionIndicator(isConnected: true),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

              const SizedBox(height: 24),

              // Summary cards row
              Row(
                children: [
                  _buildSummaryCard('87', 'Health\nScore', AppColors.success),
                  const SizedBox(width: 10),
                  _buildSummaryCard('1', 'Active\nDTCs', AppColors.warning),
                  const SizedBox(width: 10),
                  _buildSummaryCard('1', 'Active\nAnomalies', AppColors.warning),
                  const SizedBox(width: 10),
                  _buildSummaryCard('0', 'Critical', AppColors.success),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 24),

              // Quick access buttons
              Row(
                children: [
                  _buildQuickButton(context, 'Anomaly\nAnalysis', Icons.track_changes_rounded, AppColors.warning, () {
                    Navigator.pushNamed(context, AppRouter.mechanicAnomaly);
                  }),
                  const SizedBox(width: 10),
                  _buildQuickButton(context, 'DTC\nCodes', Icons.code_rounded, AppColors.primary, () {
                    Navigator.pushNamed(context, AppRouter.mechanicDtc);
                  }),
                  const SizedBox(width: 10),
                  _buildQuickButton(context, 'Vehicle\nReport', Icons.assessment_rounded, AppColors.success, () {
                    Navigator.pushNamed(context, AppRouter.mechanicReport);
                  }),
                  const SizedBox(width: 10),
                  _buildQuickButton(context, 'Vehicle\nHistory', Icons.history_rounded, AppColors.primaryDim, () {
                    Navigator.pushNamed(context, AppRouter.mechanicHistory);
                  }),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

              const SizedBox(height: 24),

              // Live Telemetry section
              SectionHeader(
                title: 'Live Telemetry',
                actionText: 'Full View',
                onAction: () => Navigator.pushNamed(context, AppRouter.mechanicTelemetry),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  TelemetryCard(label: 'Engine RPM', value: '780', unit: 'rpm', icon: Icons.speed_rounded),
                  TelemetryCard(label: 'Vehicle Speed', value: '0', unit: 'km/h', icon: Icons.directions_car_rounded),
                  TelemetryCard(label: 'Coolant Temp', value: '69', unit: '°C', icon: Icons.thermostat_rounded),
                  TelemetryCard(label: 'Intake Temp', value: '63', unit: '°C', icon: Icons.air_rounded, statusColor: AppColors.warning),
                  TelemetryCard(label: 'Engine Load', value: '12', unit: '%', icon: Icons.data_usage_rounded),
                  TelemetryCard(label: 'Throttle', value: '18.04', unit: '%', icon: Icons.tune_rounded),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

              const SizedBox(height: 12),
              TelemetryCard(label: 'Mass Air Flow', value: '0.21', unit: 'g/s', icon: Icons.waves_rounded, statusColor: AppColors.warning)
                  .animate().fadeIn(duration: 400.ms, delay: 550.ms),

              const SizedBox(height: 24),

              // Active Issues
              const SectionHeader(title: 'Active Issues'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Text('Air Intake Behavior', style: AppTextStyles.titleSmall),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('82%', style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Airflow deviation from learned baseline', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTertiary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('P0101', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                        ),
                        const SizedBox(width: 8),
                        Text('Moderate', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, AppRouter.mechanicAnomaly),
                          child: const Text('Analyze'),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.titleLarge.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label, style: AppTextStyles.labelSmall, textAlign: TextAlign.center, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}
