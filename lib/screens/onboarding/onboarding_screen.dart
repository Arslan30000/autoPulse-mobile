import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/primary_button.dart';
import 'package:autopulse_ai/navigation/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.speed_rounded,
      title: 'Know Your Vehicle',
      subtitle: 'Monitor important vehicle parameters in real time with beautiful futuristic dashboards.',
    ),
    _OnboardingSlide(
      icon: Icons.track_changes_rounded,
      title: 'Detect What Changes',
      subtitle: 'Identify unusual vehicle behavior and anomalies before they become difficult to understand.',
    ),
    _OnboardingSlide(
      icon: Icons.auto_awesome_rounded,
      title: 'Ask Your Vehicle AI',
      subtitle: 'Get understandable, evidence-based explanations from your vehicle data via smart AI assistance.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.1),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGlow.withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            slide.icon,
                            size: 90,
                            color: AppColors.primary,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 600.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 56),
                        Text(
                          slide.title,
                          style: AppTextStyles.headlineMedium,
                          textAlign: TextAlign.center,
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 200.ms)
                            .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 200.ms),
                        const SizedBox(height: 20),
                        Text(
                          slide.subtitle,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                          textAlign: TextAlign.center,
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 400.ms)
                            .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 400.ms),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _slides.length,
                    effect: ExpandingDotsEffect(
                      dotWidth: 10,
                      dotHeight: 10,
                      spacing: 12,
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.surfaceTertiary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentPage == _slides.length - 1
                        ? PrimaryButton(
                            key: const ValueKey('get_started'),
                            label: 'Get Started',
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, AppRouter.roleSelection);
                            },
                          ).animate().fadeIn().scale()
                        : Row(
                            key: const ValueKey('nav_buttons'),
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(context, AppRouter.roleSelection);
                                },
                                child: Text('Skip', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 130,
                                child: PrimaryButton(
                                  label: 'Next',
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ).animate().fadeIn(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
