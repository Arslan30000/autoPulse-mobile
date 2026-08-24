import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/health_score_widget.dart';
import 'package:autosense_ai/core/widgets/system_status_card.dart';
import 'package:autosense_ai/core/widgets/vehicle_illustration.dart';
import 'package:autosense_ai/core/widgets/primary_button.dart';
import 'package:autosense_ai/core/widgets/section_header.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';
import 'package:autosense_ai/models/health.dart';
import 'package:autosense_ai/navigation/app_router.dart';

class VehicleHealthScreen extends StatefulWidget {
  const VehicleHealthScreen({super.key});

  @override
  State<VehicleHealthScreen> createState() => _VehicleHealthScreenState();
}

class _VehicleHealthScreenState extends State<VehicleHealthScreen> {
  SystemHealth? _selectedSystem;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vehicle Health')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle illustration
              Center(
                child: VehicleIllustration(
                  systems: MockData.vehicleHealth.systems,
                  height: 220,
                ),
              ).animate().fadeIn(duration: 500.ms),

              const SizedBox(height: 24),

              // Health score
              Center(
                child: HealthScoreWidget(
                  score: MockData.vehicleHealth.score,
                  status: MockData.vehicleHealth.status,
                  size: 120,
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

              const SizedBox(height: 24),

              SectionHeader(title: 'Vehicle Systems')
                  .animate().fadeIn(duration: 400.ms, delay: 300.ms),
              const SizedBox(height: 12),

              // System cards
              ...MockData.vehicleHealth.systems.map((system) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SystemStatusCard(
                    systemHealth: system,
                    onTap: () {
                      setState(() {
                        _selectedSystem = _selectedSystem == system ? null : system;
                      });
                    },
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Selected system detail
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedSystem != null
                    ? _buildSystemDetail(_selectedSystem!)
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemDetail(SystemHealth system) {
    if (system.status == SystemStatus.normal) {
      return Container(
        key: ValueKey('detail_${system.name}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 12),
            Text(
              '${system.name} is operating normally.',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
    }

    // Anomaly detail (Air Intake)
    final anomaly = MockData.anomalies.first;
    return Container(
      key: ValueKey('detail_${system.name}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.warning, width: 3),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Possible Anomaly',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: 4),
          Text(
            'Severity: ${anomaly.severity}',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            system.description ?? anomaly.detailedDescription,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text('Supporting Telemetry', style: AppTextStyles.titleSmall),
          const SizedBox(height: 8),
          ...anomaly.supportingTelemetry.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${entry.key}  Current:', style: AppTextStyles.bodySmall),
                  Text(
                    entry.value,
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Ask AutoSense AI',
            icon: Icons.auto_awesome_rounded,
            onPressed: () => Navigator.pushNamed(context, AppRouter.aiAssistant),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}
