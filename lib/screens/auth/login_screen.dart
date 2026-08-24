import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/primary_button.dart';
import 'package:autosense_ai/navigation/app_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
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
                  child: const Icon(
                    Icons.sensors_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'AutoSense',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
              const SizedBox(height: 40),
              Text(
                'Welcome to AutoSense',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Your vehicle\'s health, explained.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
              const SizedBox(height: 40),
              // Email field
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 16),
              // Password field
              TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Password',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 24),
              // Log In
              PrimaryButton(
                label: 'Log In',
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRouter.addVehicle);
                },
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              const SizedBox(height: 12),
              // Create Account
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRouter.addVehicle);
                  },
                  child: const Text('Create Account'),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
              const SizedBox(height: 24),
              // Demo
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRouter.addVehicle);
                  },
                  child: Text(
                    'Continue as Demo',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
