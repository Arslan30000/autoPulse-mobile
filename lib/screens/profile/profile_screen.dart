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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.surfaceTertiary,
                      child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Demo User', style: AppTextStyles.titleMedium),
                          Text(MockData.vehicle.fullDisplayName, style: AppTextStyles.bodySmall),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleIcon, size: 14, color: roleColor),
                                const SizedBox(width: 4),
                                Text(
                                  roleLabel,
                                  style: AppTextStyles.labelSmall.copyWith(color: roleColor),
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
                        const Icon(Icons.bluetooth_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('OBD-II Adapter', style: AppTextStyles.titleSmall),
                            Text('ELM327', style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
                        ),
                        const SizedBox(width: 6),
                        Text('Connected', style: AppTextStyles.bodySmall.copyWith(color: AppColors.success)),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildSettingsItem(Icons.directions_car_rounded, 'My Vehicles', context),
                    const Divider(height: 1),
                    _buildSettingsItem(Icons.bluetooth_rounded, 'OBD-II Connection', context),
                    const Divider(height: 1),
                    _buildSettingsItem(Icons.notifications_outlined, 'Notifications', context),
                    const Divider(height: 1),
                    _buildSettingsItem(Icons.shield_outlined, 'Data & Privacy', context),
                    const Divider(height: 1),
                    _buildSettingsItem(Icons.auto_awesome_rounded, 'AI Settings', context),
                    const Divider(height: 1),
                    _buildSettingsItem(Icons.info_outline_rounded, 'About AutoSense', context),
                    const Divider(height: 1),
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
                            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
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
