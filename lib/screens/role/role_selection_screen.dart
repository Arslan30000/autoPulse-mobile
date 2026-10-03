import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/services/role_service.dart';
import 'package:autopulse_ai/navigation/app_router.dart';

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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGlow.withValues(alpha: 0.4),
                        blurRadius: 35,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sensors_rounded, size: 48, color: AppColors.primary),
                ),
              ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'How will you use autopulse?',
                  style: AppTextStyles.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.1),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Choose your experience to personalize the interface.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.1),
              const Spacer(flex: 1),
              
              // Car Owner Card
              _RoleCard(
                icon: Icons.directions_car_rounded,
                title: 'Car Owner',
                description: 'Monitor your vehicle\'s health, understand warnings, and get AI-powered explanations.',
                accentColor: AppColors.primary,
                onTap: () {
                  RoleService().setRole(UserRole.carOwner);
                  Navigator.pushReplacementNamed(context, AppRouter.addVehicle);
                },
              ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.1, duration: 500.ms),
              const SizedBox(height: 20),
              
              // Mechanic Card
              _RoleCard(
                icon: Icons.build_circle_rounded,
                title: 'Mechanic',
                description: 'Inspect live telemetry, diagnostic codes, anomalies, and detailed vehicle reports.',
                accentColor: AppColors.warning,
                onTap: () {
                  RoleService().setRole(UserRole.mechanic);
                  Navigator.pushReplacementNamed(context, AppRouter.addVehicle);
                },
              ).animate().fadeIn(duration: 500.ms, delay: 450.ms).slideY(begin: 0.1, duration: 500.ms),
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
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: accentColor.withValues(alpha: 0.1),
      highlightColor: accentColor.withValues(alpha: 0.05),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Icon(icon, color: accentColor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_rounded, color: accentColor, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
