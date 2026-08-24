import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';

class HealthScoreWidget extends StatelessWidget {
  final int score;
  final String status;
  final double size;

  const HealthScoreWidget({
    super.key,
    required this.score,
    required this.status,
    this.size = 200,
  });

  Color get _progressColor {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: size / 2,
      lineWidth: 12,
      percent: score / 100,
      animation: true,
      animationDuration: 1200,
      animateFromLastPercent: true,
      circularStrokeCap: CircularStrokeCap.round,
      progressColor: _progressColor,
      backgroundColor: AppColors.surfaceTertiary,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: size < 160
                    ? AppTextStyles.telemetryValue.copyWith(fontSize: 36)
                    : AppTextStyles.healthScore,
              ),
              Text(
                ' /100',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: AppTextStyles.healthLabel.copyWith(color: _progressColor),
          ),
        ],
      ),
    );
  }
}
