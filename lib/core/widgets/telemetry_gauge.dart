import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';

class TelemetryGauge extends StatelessWidget {
  final String label;
  final String unit;
  final double? value;
  final double minimum;
  final double maximum;
  final String quality;
  final int divisions;
  final double tickDivisor;
  final Color accentColor;
  const TelemetryGauge({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.maximum,
    required this.quality,
    this.minimum = 0,
    this.divisions = 6,
    this.tickDivisor = 1,
    this.accentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: ${value == null ? quality : '${value!.round()} $unit'}.',
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.titleSmall.copyWith(letterSpacing: .3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final diameter = constraints.maxWidth;
                return CustomPaint(
                  painter: _GaugePainter(
                    fraction: value == null
                        ? null
                        : ((value! - minimum) / (maximum - minimum)).clamp(
                            0,
                            1,
                          ),
                    minimum: minimum,
                    maximum: maximum,
                    divisions: divisions,
                    tickDivisor: tickDivisor,
                    accentColor: accentColor,
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: diameter * .36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            child: Text(
                              value?.round().toString() ?? '--',
                              style: AppTextStyles.telemetryValue.copyWith(
                                fontSize: (diameter * .23).clamp(24, 64),
                                height: 1.1,
                              ),
                            ),
                          ),
                          Text(
                            unit,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: (diameter * .055).clamp(10, 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Text(
            quality,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 11,
              color: value == null ? AppColors.textTertiary : accentColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    ),
  );
}

class _GaugePainter extends CustomPainter {
  final double? fraction;
  final double minimum, maximum, tickDivisor;
  final int divisions;
  final Color accentColor;
  _GaugePainter({
    required this.fraction,
    required this.minimum,
    required this.maximum,
    required this.divisions,
    required this.tickDivisor,
    required this.accentColor,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * .46;
    const start = math.pi * .75;
    const sweep = math.pi * 1.5;
    Offset point(double a, double r) =>
        center + Offset(math.cos(a) * r, math.sin(a) * r);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    line
      ..color = AppColors.border
      ..strokeWidth = size.width * .025;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      line,
    );
    if (fraction != null) {
      line
        ..color = accentColor
        ..strokeWidth = size.width * .025;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * fraction!,
        false,
        line,
      );
    }
    final ticks = divisions * 5;
    for (var i = 0; i <= ticks; i++) {
      final angle = start + sweep * i / ticks;
      final major = i % 5 == 0;
      line
        ..color = major ? AppColors.textSecondary : AppColors.borderLight
        ..strokeWidth = major ? 1.8 : 1;
      canvas.drawLine(
        point(angle, radius - size.width * .045),
        point(angle, radius - size.width * (major ? .095 : .07)),
        line,
      );
      if (major && size.width >= 90) {
        final tick = ((minimum + (maximum - minimum) * i / ticks) / tickDivisor)
            .round()
            .toString();
        final label = tickDivisor == 1000 && tick != '0' ? '${tick}k' : tick;
        final text = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: (size.width * .052).clamp(8, 13),
              color: AppColors.textSecondary,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          point(angle, radius - size.width * .16) -
              Offset(text.width / 2, text.height / 2),
        );
      }
    }
    if (fraction != null) {
      final angle = start + sweep * fraction!;
      line
        ..color = AppColors.textPrimary
        ..strokeWidth = size.width * .012;
      canvas.drawLine(
        point(angle + math.pi, radius * .13),
        point(angle, radius * .62),
        line,
      );
    }
    canvas.drawCircle(
      center,
      size.width * .023,
      Paint()..color = fraction == null ? AppColors.borderLight : accentColor,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction ||
      old.minimum != minimum ||
      old.maximum != maximum ||
      old.divisions != divisions ||
      old.tickDivisor != tickDivisor ||
      old.accentColor != accentColor;
}
