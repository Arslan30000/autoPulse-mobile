import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';

/// Shared vector identity for the app and generated platform icons.
class BrandMark extends StatelessWidget {
  final double width;
  const BrandMark({super.key, this.width = 180});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'AutoPulseAI',
    image: true,
    child: ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width * .52,
              height: width * .52,
              child: const CustomPaint(painter: BrandEmblemPainter()),
            ),
            SizedBox(height: width * .045),
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'AutoPulse'),
                  TextSpan(
                    text: 'AI',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textPrimary,
                fontSize: width * .16,
                height: 1.15,
                letterSpacing: -width * .003,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Angular road-inspired A with a telemetry pulse as its crossbar.
class BrandEmblemPainter extends CustomPainter {
  const BrandEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final fill = Paint()..color = AppColors.textPrimary;
    canvas.drawPath(
      Path()
        ..moveTo(10, 84)
        ..lineTo(42, 16)
        ..lineTo(54, 16)
        ..lineTo(22, 84)
        ..close(),
      fill,
    );
    fill.color = AppColors.primary;
    canvas.drawPath(
      Path()
        ..moveTo(54, 16)
        ..lineTo(90, 84)
        ..lineTo(76, 84)
        ..lineTo(47, 29)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(26, 62)
        ..lineTo(39, 62)
        ..lineTo(45, 49)
        ..lineTo(52, 71)
        ..lineTo(58, 60)
        ..lineTo(73, 60),
      Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.miter,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BrandEmblemPainter oldDelegate) => false;
}
