import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/models/driving_context.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';

Color contextColor(DrivingState state) => switch (state) {
  DrivingState.cityCruising ||
  DrivingState.highwayCruising => AppColors.success,
  DrivingState.heavyLoad => AppColors.warning,
  DrivingState.aggressiveAcceleration => AppColors.danger,
  _ => AppColors.primary,
};

IconData contextIcon(DrivingState state) => switch (state) {
  DrivingState.idling => Icons.local_parking_rounded,
  DrivingState.engineOff => Icons.power_settings_new_rounded,
  DrivingState.cityCruising => Icons.location_city_rounded,
  DrivingState.highwayCruising => Icons.add_road_rounded,
  DrivingState.heavyLoad => Icons.landscape_rounded,
  DrivingState.aggressiveAcceleration => Icons.speed_rounded,
  DrivingState.accelerating => Icons.trending_up_rounded,
  DrivingState.decelerating => Icons.trending_down_rounded,
  _ => Icons.sensors_rounded,
};

class DrivingContextCard extends StatelessWidget {
  const DrivingContextCard({super.key, required this.controller});
  final DrivingContextController controller;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: controller,
    child: Consumer<DrivingContextController>(
      builder: (context, controller, _) {
        final snapshot = controller.current;
        final color = contextColor(snapshot.state);
        return Semantics(
          container: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                color.withValues(alpha: .07),
                AppColors.surface,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(contextIcon(snapshot.state), color: color, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Driving Context',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(snapshot.state.label, style: AppTextStyles.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  snapshot.state.description,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                ),
                if (snapshot.highDemand &&
                    snapshot.state != DrivingState.heavyLoad) ...[
                  const SizedBox(height: 8),
                  Text(
                    'High engine demand',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  snapshot.state.isOperating
                      ? switch (snapshot.source) {
                          ContextSource.model =>
                            'Live estimate · On-device model',
                          ContextSource.experimentalModel =>
                            'Live estimate · Experimental model + rules',
                          ContextSource.rules =>
                            'Live estimate · Provisional rules',
                        }
                      : snapshot.state == DrivingState.disconnected
                      ? 'Available when connected'
                      : 'Waiting for fresh OBD-II signals',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
