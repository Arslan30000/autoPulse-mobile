import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/connection_indicator.dart';
import 'package:autopulse_ai/core/widgets/section_header.dart';
import 'package:autopulse_ai/core/widgets/telemetry_card.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'dart:ui';

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
              // Premium Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.background,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Diagnostic Center', style: AppTextStyles.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(MockData.vehicle.fullDisplayName, style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        const ConnectionIndicator(isConnected: true),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOutCubic).slideY(begin: -0.1, end: 0),

              const SizedBox(height: 24),

              // Summary cards row
              Row(
                children: [
                  _buildSummaryCard('87', 'Health\nScore', AppColors.success),
                  const SizedBox(width: 10),
                  _buildSummaryCard('1', 'Active\nDTCs', AppColors.warning),
                  const SizedBox(width: 10),
                  _buildSummaryCard('1', 'Active\nAlerts', AppColors.warning),
                  const SizedBox(width: 10),
                  _buildSummaryCard('0', 'Critical\nIssues', AppColors.success),
                ],
              ).animate().fadeIn(duration: 600.ms, delay: 150.ms, curve: Curves.easeOutCubic).slideY(begin: 0.1, end: 0),

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
              ).animate().fadeIn(duration: 600.ms, delay: 300.ms, curve: Curves.easeOutCubic).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 24),

              // Live Telemetry section
              SectionHeader(
                title: 'Live Telemetry',
                actionText: 'Full View',
                onAction: () => Navigator.pushNamed(context, AppRouter.mechanicTelemetry),
              ).animate().fadeIn(duration: 600.ms, delay: 450.ms),
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
              ).animate().fadeIn(duration: 600.ms, delay: 550.ms).slideX(begin: 0.05, end: 0),

              const SizedBox(height: 12),
              TelemetryCard(label: 'Mass Air Flow', value: '0.21', unit: 'g/s', icon: Icons.waves_rounded, statusColor: AppColors.warning)
                  .animate().fadeIn(duration: 600.ms, delay: 600.ms).slideX(begin: 0.05, end: 0),

              const SizedBox(height: 32),

              // Active Issues (Critical Alert Style)
              const SectionHeader(title: 'Active Issues').animate().fadeIn(duration: 600.ms, delay: 700.ms),
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warning, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                  gradient: LinearGradient(
                    colors: [
                      AppColors.warning.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_rounded, color: AppColors.warning, size: 24)
                            .animate(onPlay: (controller) => controller.repeat(reverse: true))
                            .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
                        const SizedBox(width: 12),
                        Text('Air Intake Behavior', style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        )),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                          ),
                          child: Text('82%', style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w900,
                          )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Airflow deviation from learned baseline indicates potential intake leak or MAF degradation.', 
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTertiary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text('P0101', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Moderate', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning), overflow: TextOverflow.ellipsis),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRouter.mechanicAnomaly),
                          icon: const Icon(Icons.analytics_rounded, size: 16),
                          label: const Text('Analyze', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                            foregroundColor: AppColors.warning,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 800.ms).scale(begin: const Offset(0.95, 0.95)),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ]
            )),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: 0.2),
          highlightColor: color.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 8),
                Text(label, style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ), textAlign: TextAlign.center, maxLines: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
