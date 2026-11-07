import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/brand_mark.dart';
import 'package:autopulse_ai/core/widgets/primary_button.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _busy = false;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 2) {
      await _pages.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await OnboardingService.complete();
      if (mounted) Navigator.pushReplacementNamed(context, AppRouter.login);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save setup. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Row(
                  children: [
                    const BrandMark(width: 88),
                    const Spacer(),
                    Text('0${_page + 1} / 03', style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (value) => setState(() => _page = value),
                  children: [
                    _slide(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Welcome to',
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 36),
                          const BrandMark(width: 230),
                          const SizedBox(height: 36),
                          Text(
                            'A little insight.\nA healthier drive.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AI insights to help you understand your vehicle’s health and track changes over time.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _slide(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set up your adapter',
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Three steps to get connected.',
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/adapter-setup.png',
                              height: 170,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _step(
                            '1',
                            'Plug in your ELM327',
                            'With the ignition off, find the OBD-II port, usually beneath the driver’s dashboard.',
                          ),
                          _step(
                            '2',
                            'Switch the ignition on',
                            'After plugging in, turn the ignition to ON so the vehicle ECU can communicate.',
                          ),
                          _step(
                            '3',
                            'Pair using Bluetooth',
                            'Pair the adapter in Android Bluetooth settings, then tap Connect on Home.',
                          ),
                        ],
                      ),
                    ),
                    _slide(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/branding/assistant.png',
                            height: 185,
                            width: 185,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Meet your AI assistant',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Make sense of what your car is telling you.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: 32),
                          _benefit(
                            Icons.chat_bubble_outline_rounded,
                            'Ask questions about your vehicle in everyday language.',
                          ),
                          _benefit(
                            Icons.insights_rounded,
                            'Get clear explanations of readings and changes over time.',
                          ),
                          _benefit(
                            Icons.manage_search_rounded,
                            'Explore possible causes and suggested next checks.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 12, 32, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _page ? 26 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.primary
                                : AppColors.borderLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _page == 0
                          ? 'Continue'
                          : _page == 1
                          ? 'Next'
                          : 'Get Started',
                      icon: Icons.arrow_forward_rounded,
                      isLoading: _busy,
                      onPressed: _busy ? null : _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _slide(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity),
        ),
        child: child,
      ),
    ),
  );

  Widget _step(String number, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            number,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleMedium),
              const SizedBox(height: 5),
              Text(text, style: AppTextStyles.bodyMedium.copyWith(height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _benefit(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyLarge.copyWith(height: 1.5),
          ),
        ),
      ],
    ),
  );
}
