import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/primary_button.dart';
import 'package:autosense_ai/navigation/app_router.dart';

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
      subtitle: 'Monitor important vehicle parameters in real time.',
    ),
    _OnboardingSlide(
      icon: Icons.track_changes_rounded,
      title: 'Detect What Changes',
      subtitle: 'Identify unusual vehicle behavior before it becomes difficult to understand.',
    ),
    _OnboardingSlide(
      icon: Icons.auto_awesome_rounded,
      title: 'Ask Your Vehicle AI',
      subtitle: 'Get understandable, evidence-based explanations from your vehicle data.',
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
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.1),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGlow,
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            slide.icon,
                            size: 80,
                            color: AppColors.primary,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 500.ms),
                        const SizedBox(height: 48),
                        Text(
                          slide.title,
                          style: AppTextStyles.headlineMedium,
                          textAlign: TextAlign.center,
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 200.ms)
                            .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 200.ms),
                        const SizedBox(height: 16),
                        Text(
                          slide.subtitle,
                          style: AppTextStyles.bodyMedium,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _slides.length,
                    effect: const WormEffect(
                      dotWidth: 8,
                      dotHeight: 8,
                      spacing: 12,
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.surfaceTertiary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_currentPage == _slides.length - 1)
                    PrimaryButton(
                      label: 'Get Started',
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, AppRouter.login);
                      },
                    )
                  else
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, AppRouter.login);
                          },
                          child: Text('Skip', style: AppTextStyles.bodyMedium),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 120,
                          child: PrimaryButton(
                            label: 'Next',
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ],
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
