import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/section_header.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';
import 'package:autosense_ai/services/role_service.dart';
import 'package:autosense_ai/navigation/app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = RoleService().currentRole;
    final roleLabel = role == UserRole.carOwner ? 'Car Owner' : 'Mechanic';
    final roleIcon = role == UserRole.carOwner ? Icons.directions_car_rounded : Icons.build_circle_rounded;
    final roleColor = role == UserRole.carOwner ? AppColors.primary : AppColors.warning;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: AppTextStyles.headlineMedium)
                  .animate().fadeIn(duration: 500.ms),

              const SizedBox(height: 24),

              // User card with role badge
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surface.withValues(alpha: 0.7),
                      AppColors.surface.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 16,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.surfaceTertiary,
                        child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Demo User', style: AppTextStyles.titleLarge),
                          Text(MockData.vehicle.fullDisplayName, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleIcon, size: 16, color: roleColor),
                                const SizedBox(width: 6),
                                Text(
                                  roleLabel,
                                  style: AppTextStyles.labelSmall.copyWith(color: roleColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

              const SizedBox(height: 24),

              // OBD-II card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surface.withValues(alpha: 0.5),
                      AppColors.surface.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.1),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bluetooth_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('OBD-II Adapter', style: AppTextStyles.titleMedium),
                            Text('ELM327', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, 
                            color: AppColors.success,
                            boxShadow: [
                              BoxShadow(color: AppColors.success.withValues(alpha: 0.6), blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Connected', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 24),

              const SectionHeader(title: 'Settings'),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _buildSettingsItem(Icons.directions_car_rounded, 'My Vehicles', context),
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
                    _buildSettingsItem(Icons.bluetooth_rounded, 'OBD-II Connection', context),
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
                    _buildSettingsItem(Icons.notifications_outlined, 'Notifications', context),
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
                    _buildSettingsItem(Icons.shield_outlined, 'Data & Privacy', context),
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
                    _buildSettingsItem(Icons.auto_awesome_rounded, 'AI Settings', context),
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
                    _buildSettingsItem(Icons.info_outline_rounded, 'About AutoSense', context),
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
                    // Switch Role
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, AppRouter.roleSelection);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz_rounded, color: AppColors.warning, size: 22),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Switch Role',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.warning),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

              const SizedBox(height: 24),
              Center(child: Text('AutoSense v1.0.0', style: AppTextStyles.labelSmall))
                  .animate().fadeIn(duration: 400.ms, delay: 500.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
