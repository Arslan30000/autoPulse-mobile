import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/account_data_service.dart';
import 'package:autopulse_ai/models/vehicle.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      final data = AccountDataService.instance;
      Vehicle? vehicle;
      try {
        vehicle = await data.restoreSelection(cloud: false);
        if (vehicle == null && AccountService.instance.userId != null) {
          vehicle = await data.restoreSelection();
        }
      } catch (_) {
        // A failed cache read leaves sign-in and offline recovery available.
      }
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          vehicle != null ? AppRouter.main : AppRouter.login,
        );
      }
      if (AccountService.instance.userId != null) {
        await AccountDataService.instance.synchronize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGlow,
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: AppColors.primary,
                    size: 64,
                  ),
                )
                .animate()
                .fadeIn(duration: 600.ms, delay: 200.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  delay: 200.ms,
                ),
            const SizedBox(height: 24),
            Text(
              'AutoPulseAI',
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
            const SizedBox(height: 8),
            Text(
              'Understand Your Vehicle.',
              style: AppTextStyles.bodyMedium,
            ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
