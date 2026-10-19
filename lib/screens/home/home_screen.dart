import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/brand_mark.dart';
import 'package:autopulse_ai/core/widgets/vehicle_illustration.dart';
import 'package:autopulse_ai/core/widgets/obd_connection_panel.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/screens/vehicle/vehicles_screen.dart';
import 'package:autopulse_ai/screens/history/recordings_screen.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _connect(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connect your vehicle', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Pair your ELM327 in Android Bluetooth settings first.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            ObdConnectionPanel(controller: ObdController.instance),
          ],
        ),
      ),
    ),
  );

  void _history(BuildContext context) {
    final store = ObdController.instance.repository;
    if (store is! RecordingStore) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            RecordingsScreen(store: store, sync: RecordingSyncService.instance),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(width: 92),
                    const Spacer(),
                    ListenableBuilder(
                      listenable: ObdController.instance,
                      builder: (_, _) => TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => _connect(context),
                        icon: Icon(
                          ObdController.instance.isReady
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth,
                          size: 17,
                        ),
                        label: Text(
                          ObdController.instance.isReady
                              ? 'Connected'
                              : 'Connect Bluetooth',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(_greeting(), style: AppTextStyles.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  'Your drive, understood.',
                  style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 10, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ListenableBuilder(
                                listenable: ObdController.instance,
                                builder: (_, _) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MY VEHICLE',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        letterSpacing: 1.8,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      ObdController
                                          .instance
                                          .vehicle
                                          .fullDisplayName,
                                      style: AppTextStyles.titleLarge,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Change vehicle',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const VehiclesScreen(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.swap_horiz_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VehicleIllustration(height: 235),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 12, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: ListenableBuilder(
                                listenable: ObdController.instance,
                                builder: (_, _) => Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 7,
                                      color: ObdController.instance.isReady
                                          ? AppColors.success
                                          : AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        ObdController.instance.isReady
                                            ? 'Receiving vehicle data'
                                            : 'Ready when you are',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const VehiclePreviewScreen(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.view_in_ar_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Explore 3D',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Your vehicle toolkit', style: AppTextStyles.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Everything you need for a clearer picture.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) => GridView.count(
                    crossAxisCount: constraints.maxWidth >= 650 ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 120,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _action(
                        context,
                        'Live Monitor',
                        'See real-time readings',
                        Icons.speed_rounded,
                        () => Navigator.pushNamed(context, AppRouter.live),
                      ),
                      _action(
                        context,
                        'Diagnostics',
                        'Understand fault codes',
                        Icons.build_outlined,
                        () =>
                            Navigator.pushNamed(context, AppRouter.diagnostics),
                      ),
                      _action(
                        context,
                        'AI assistant',
                        'Ask about your vehicle',
                        Icons.auto_awesome_rounded,
                        () =>
                            Navigator.pushNamed(context, AppRouter.aiAssistant),
                        featured: true,
                      ),
                      _action(
                        context,
                        'Vehicle health',
                        'See the bigger picture',
                        Icons.favorite_border_rounded,
                        () => Navigator.pushNamed(
                          context,
                          AppRouter.vehicleHealth,
                        ),
                      ),
                      _action(
                        context,
                        'History',
                        'Revisit saved drives',
                        Icons.history_rounded,
                        () => _history(context),
                      ),
                      _action(
                        context,
                        'Drive report',
                        'Review your journey',
                        Icons.assessment_outlined,
                        () =>
                            Navigator.pushNamed(context, AppRouter.driveReport),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tips_and_updates_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Connect your adapter to see live readings and record your next drive.',
                          style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String _greeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final name = AccountService.instance.displayName.trim();
    return name.isEmpty ? greeting : '$greeting, ${name.split(' ').first}';
  }

  Widget _action(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool featured = false,
  }) => Material(
    color: featured ? AppColors.tealSurface : AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: featured
                ? AppColors.primary.withValues(alpha: .5)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: featured ? AppColors.textPrimary : AppColors.primary,
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
