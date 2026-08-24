import 'package:flutter/material.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/models/health.dart';

class SystemStatusCard extends StatelessWidget {
  final SystemHealth systemHealth;
  final VoidCallback? onTap;

  const SystemStatusCard({
    super.key,
    required this.systemHealth,
    this.onTap,
  });

  Color get _statusColor {
    switch (systemHealth.status) {
      case SystemStatus.normal:
        return AppColors.success;
      case SystemStatus.attention:
        return AppColors.warning;
      case SystemStatus.warning:
        return AppColors.warningDim;
      case SystemStatus.critical:
        return AppColors.danger;
    }
  }

  IconData get _statusIcon {
    switch (systemHealth.status) {
      case SystemStatus.normal:
        return Icons.check_circle_rounded;
      case SystemStatus.attention:
        return Icons.warning_amber_rounded;
      case SystemStatus.warning:
        return Icons.warning_rounded;
      case SystemStatus.critical:
        return Icons.error_rounded;
    }
  }

  IconData get _systemIcon {
    switch (systemHealth.icon) {
      case 'engine':
        return Icons.settings_rounded;
      case 'cooling':
        return Icons.thermostat_rounded;
      case 'air_intake':
        return Icons.air_rounded;
      case 'sensors':
        return Icons.sensors_rounded;
      case 'electrical':
        return Icons.electrical_services_rounded;
      case 'transmission':
        return Icons.swap_vert_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Icon(_systemIcon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(systemHealth.name, style: AppTextStyles.titleSmall),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(_statusIcon, color: _statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        systemHealth.statusLabel,
                        style: AppTextStyles.bodySmall.copyWith(color: _statusColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
