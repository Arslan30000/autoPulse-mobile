import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';

class DiagnosticCard extends StatelessWidget {
  final String title;
  final String severity;
  final String description;
  final String status;
  final VoidCallback? onAction;
  final String actionLabel;

  const DiagnosticCard({
    super.key,
    required this.title,
    required this.severity,
    required this.description,
    required this.status,
    this.onAction,
    this.actionLabel = 'Analyze',
  });

  Color get _severityColor {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppColors.danger;
      case 'moderate':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _severityColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppTextStyles.titleSmall),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _severityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  severity,
                  style: AppTextStyles.labelSmall.copyWith(color: _severityColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _severityColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: AppTextStyles.bodySmall.copyWith(color: _severityColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
