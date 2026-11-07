import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/models/health.dart';

class SystemStatusCard extends StatelessWidget {
  final SystemHealth systemHealth;
  final VoidCallback? onTap;
  final bool selected;

  const SystemStatusCard({
    super.key,
    required this.systemHealth,
    this.onTap,
    this.selected = false,
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
    final accent = systemHealth.status == SystemStatus.normal
        ? AppColors.primary
        : _statusColor;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? AppColors.surfaceSecondary : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? accent : accent.withValues(alpha: .12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_systemIcon, color: accent, size: 25),
                    ),
                    if (onTap != null)
                      Icon(
                        selected
                            ? Icons.expand_less_rounded
                            : Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  systemHealth.name,
                  style: AppTextStyles.titleSmall.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(_statusIcon, color: _statusColor, size: 13),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        systemHealth.statusLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
