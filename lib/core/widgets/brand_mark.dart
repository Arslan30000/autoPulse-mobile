import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';

/// A pulse mark for AutoPulseAI, used consistently across app surfaces.
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
              width: width,
              height: width * .46,
              child: CustomPaint(painter: _BrandPainter()),
            ),
            Text.rich(
              TextSpan(
                children: const [
                  TextSpan(text: 'AutoPulse'),
                  TextSpan(
                    text: 'AI',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: width * .16,
                height: 1.15,
                letterSpacing: -.7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 180, size.height / 82);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    outline.color = AppColors.textPrimary;
    canvas.drawPath(
      Path()
        ..moveTo(28, 74)
        ..lineTo(90, 8)
        ..lineTo(152, 74),
      outline,
    );
    canvas.drawLine(const Offset(58, 47), const Offset(75, 47), outline);
    canvas.drawLine(const Offset(105, 47), const Offset(122, 47), outline);
    outline.color = AppColors.primary;
    canvas.drawPath(
      Path()
        ..moveTo(10, 48)
        ..lineTo(48, 48)
        ..lineTo(59, 35)
        ..lineTo(71, 62)
        ..lineTo(84, 21)
        ..lineTo(98, 48)
        ..lineTo(170, 48),
      outline,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

