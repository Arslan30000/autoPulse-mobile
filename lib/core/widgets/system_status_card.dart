import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/models/health.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Icon(_systemIcon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    systemHealth.name,
                    style: AppTextStyles.titleSmall.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(_statusIcon, color: _statusColor, size: 12),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          systemHealth.statusLabel,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _statusColor,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}
