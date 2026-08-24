import 'package:flutter/material.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/models/vehicle.dart';
import 'package:autosense_ai/core/widgets/connection_indicator.dart';

class VehicleHeader extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleHeader({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(vehicle.displayName, style: AppTextStyles.titleLarge),
        const SizedBox(height: 4),
        Text('${vehicle.year}', style: AppTextStyles.bodyMedium),
        if (vehicle.isConnected) ...[
          const SizedBox(height: 8),
          ConnectionIndicator(isConnected: vehicle.isConnected),
        ],
      ],
    );
  }
}
