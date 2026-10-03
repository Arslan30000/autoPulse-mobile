import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/health_score_widget.dart';
import 'package:autopulse_ai/core/widgets/system_status_card.dart';
import 'package:autopulse_ai/core/widgets/connection_indicator.dart';
import 'package:autopulse_ai/core/widgets/section_header.dart';
import 'package:autopulse_ai/core/widgets/quick_action_card.dart';
import 'package:autopulse_ai/core/widgets/vehicle_illustration.dart';
import 'package:autopulse_ai/core/widgets/alert_card.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/models/health.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.surfaceSecondary,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Text(
                  'Good Morning 👋',
                  style: AppTextStyles.headlineMedium,
                ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                const SizedBox(height: 4),
                Row(
                      children: [
                        Text(
                          MockData.vehicle.fullDisplayName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTertiary.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const ConnectionIndicator(isConnected: true),
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 100.ms)
                    .slideX(begin: 0.1),

                const SizedBox(height: 24),

                // Vehicle Health
                SectionHeader(
                  title: 'Vehicle Health',
                  actionText: 'Details',
                  onAction: () =>
                      Navigator.pushNamed(context, AppRouter.vehicleHealth),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                const SizedBox(height: 16),
                Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: HealthScoreWidget(
                          score: MockData.vehicleHealth.score,
                          status: MockData.vehicleHealth.status,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 300.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 24),

                // Vehicle Illustration
                Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 250,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  blurRadius: 50,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          VehicleIllustration(
                            systems: MockData.vehicleHealth.systems,
                            height: 180,
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 400.ms)
                    .slideY(begin: 0.2),

                const SizedBox(height: 24),

                // Systems
                SectionHeader(title: 'Systems')
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 500.ms),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: MockData.vehicleHealth.systems.map((system) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: system.status != SystemStatus.normal
                            ? [
                                BoxShadow(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: SystemStatusCard(
                        systemHealth: system,
                        onTap: system.status != SystemStatus.normal
                            ? () => Navigator.pushNamed(
                                context,
                                AppRouter.diagnosticDetail,
                                arguments: MockData.anomalies.first,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

                const SizedBox(height: 24),

                // Recent Alert
                Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: AlertCard(
                            message: 'Air intake behavior shows a minor deviation from the vehicle\'s normal pattern.',
                            onViewDetails: () => Navigator.pushNamed(
                              context,
                              AppRouter.diagnosticDetail,
                              arguments: MockData.anomalies.first,
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 700.ms)
                    .shimmer(
                      duration: 2.seconds,
                      color: AppColors.warning.withValues(alpha: 0.2),
                    ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Last Scan • Today • 12:28 PM',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 750.ms),

                const SizedBox(height: 24),

                // Quick Actions
                SectionHeader(title: 'Quick Actions')
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 800.ms),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    QuickActionCard(
                      label: 'Live Monitor',
                      icon: Icons.speed_rounded,
                      onTap: () => Navigator.pushNamed(context, AppRouter.live),
                    ),
                    QuickActionCard(
                      label: 'Diagnostics',
                      icon: Icons.build_rounded,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.diagnosticDetail,
                        arguments: MockData.anomalies.first,
                      ),
                      color: AppColors.warning,
                    ),
                    QuickActionCard(
                      label: 'AI Assistant',
                      icon: Icons.auto_awesome_rounded,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRouter.aiAssistant),
                    ),
                    QuickActionCard(
                      label: 'Health',
                      icon: Icons.favorite_rounded,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRouter.vehicleHealth),
                    ),
                    QuickActionCard(
                      label: 'History',
                      icon: Icons.timeline_rounded,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRouter.healthHistory),
                    ),
                    QuickActionCard(
                      label: 'Report',
                      icon: Icons.assessment_rounded,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRouter.driveReport),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 900.ms),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
