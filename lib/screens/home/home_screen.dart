import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/health_score_widget.dart';
import 'package:autosense_ai/core/widgets/system_status_card.dart';
import 'package:autosense_ai/core/widgets/connection_indicator.dart';
import 'package:autosense_ai/core/widgets/section_header.dart';
import 'package:autosense_ai/core/widgets/quick_action_card.dart';
import 'package:autosense_ai/core/widgets/vehicle_illustration.dart';
import 'package:autosense_ai/core/widgets/alert_card.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';
import 'package:autosense_ai/navigation/app_router.dart';
import 'package:autosense_ai/models/health.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              // Greeting
              Text('Good Morning 👋', style: AppTextStyles.headlineMedium)
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

              // Vehicle Health
              SectionHeader(
                title: 'Vehicle Health',
                actionText: 'Details',
                onAction: () => Navigator.pushNamed(context, AppRouter.vehicleHealth),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              const SizedBox(height: 16),
              Center(
                child: HealthScoreWidget(
                  score: MockData.vehicleHealth.score,
                  status: MockData.vehicleHealth.status,
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 300.ms).scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.0, 1.0),
                    duration: 600.ms,
                    delay: 300.ms,
                  ),

              const SizedBox(height: 24),

              // Vehicle Illustration
              Center(
                child: VehicleIllustration(
                  systems: MockData.vehicleHealth.systems,
                  height: 180,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

              const SizedBox(height: 24),

              // Systems
              SectionHeader(title: 'Systems')
                  .animate().fadeIn(duration: 400.ms, delay: 500.ms),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3.0,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: MockData.vehicleHealth.systems.map((system) {
                  return SystemStatusCard(
                    systemHealth: system,
                    onTap: system.status != SystemStatus.normal
                        ? () => Navigator.pushNamed(
                              context,
                              AppRouter.diagnosticDetail,
                              arguments: MockData.anomalies.first,
                            )
                        : null,
                  );
                }).toList(),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

              const SizedBox(height: 24),

              // Recent Alert
              AlertCard(
                message: 'Air intake behavior shows a minor deviation from the vehicle\'s normal pattern.',
                onViewDetails: () => Navigator.pushNamed(
                  context,
                  AppRouter.diagnosticDetail,
                  arguments: MockData.anomalies.first,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 700.ms),

              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('Last Scan  •  Today • 12:28 PM', style: AppTextStyles.labelSmall),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 750.ms),

              const SizedBox(height: 24),

              // Quick Actions
              SectionHeader(title: 'Quick Actions')
                  .animate().fadeIn(duration: 400.ms, delay: 800.ms),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: QuickActionCard(
                      label: 'Live Monitor',
                      icon: Icons.speed_rounded,
                      onTap: () => Navigator.pushNamed(context, AppRouter.live),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QuickActionCard(
                      label: 'Diagnostics',
                      icon: Icons.build_rounded,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.diagnosticDetail,
                        arguments: MockData.anomalies.first,
                      ),
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QuickActionCard(
                      label: 'AI Assistant',
                      icon: Icons.auto_awesome_rounded,
                      onTap: () => Navigator.pushNamed(context, AppRouter.aiAssistant),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 900.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
