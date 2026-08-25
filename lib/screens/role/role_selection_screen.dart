import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/services/role_service.dart';
import 'package:autosense_ai/navigation/app_router.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 1),
              // Logo
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGlow,
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sensors_rounded, size: 40, color: AppColors.primary),
                ),
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'How will you use AutoSense?',
                  style: AppTextStyles.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Choose your experience.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              const Spacer(flex: 1),
              // Car Owner Card
              _RoleCard(
                icon: Icons.directions_car_rounded,
                title: 'Car Owner',
                description: 'Monitor your vehicle\'s health, understand warnings, and get AI-powered explanations.',
                buttonLabel: 'Continue as Car Owner',
                accentColor: AppColors.primary,
                onTap: () {
                  RoleService().setRole(UserRole.carOwner);
                  Navigator.pushReplacementNamed(context, AppRouter.addVehicle);
                },
              ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 300.ms),
              const SizedBox(height: 16),
              // Mechanic Card
              _RoleCard(
                icon: Icons.build_circle_rounded,
                title: 'Mechanic',
                description: 'Inspect live telemetry, diagnostic codes, anomalies, and detailed vehicle reports.',
                buttonLabel: 'Continue as Mechanic',
                accentColor: AppColors.warning,
                onTap: () {
                  RoleService().setRole(UserRole.mechanic);
                  Navigator.pushReplacementNamed(context, AppRouter.addVehicle);
                },
              ).animate().fadeIn(duration: 500.ms, delay: 450.ms).slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 450.ms),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: accentColor, size: 22),
          ],
        ),
      ),
    );
  }
}
