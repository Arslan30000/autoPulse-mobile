import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';

/// Vector version of the supplied car/pulse mark for dark surfaces.
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
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    line.color = AppColors.primary;
    canvas.drawPath(
      Path()
        ..moveTo(3, 46)
        ..lineTo(10, 46)
        ..lineTo(16, 32)
        ..lineTo(23, 61)
        ..lineTo(30, 18)
        ..lineTo(36, 46)
        ..lineTo(46, 46),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(134, 46)
        ..lineTo(144, 46)
        ..lineTo(150, 18)
        ..lineTo(157, 61)
        ..lineTo(164, 32)
        ..lineTo(170, 46)
        ..lineTo(177, 46),
      line,
    );
    line.color = AppColors.textPrimary;
    canvas.drawPath(
      Path()
        ..moveTo(53, 31)
        ..lineTo(65, 10)
        ..quadraticBezierTo(68, 5, 75, 5)
        ..lineTo(106, 5)
        ..quadraticBezierTo(113, 5, 116, 10)
        ..lineTo(128, 31)
        ..lineTo(135, 43)
        ..lineTo(132, 62)
        ..lineTo(48, 62)
        ..lineTo(45, 43)
        ..close(),
      line,
    );
    canvas.drawLine(const Offset(53, 31), const Offset(128, 31), line);
    canvas.drawPath(
      Path()
        ..moveTo(50, 63)
        ..lineTo(50, 73)
        ..quadraticBezierTo(50, 77, 55, 77)
        ..lineTo(61, 77)
        ..quadraticBezierTo(65, 77, 65, 73)
        ..lineTo(65, 63),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(115, 63)
        ..lineTo(115, 73)
        ..quadraticBezierTo(115, 77, 120, 77)
        ..lineTo(126, 77)
        ..quadraticBezierTo(131, 77, 131, 73)
        ..lineTo(131, 63),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(56, 43)
        ..lineTo(64, 43)
        ..lineTo(69, 53)
        ..lineTo(59, 53)
        ..close(),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(124, 43)
        ..lineTo(116, 43)
        ..lineTo(111, 53)
        ..lineTo(121, 53)
        ..close(),
      line,
    );
    canvas.drawLine(const Offset(76, 53), const Offset(104, 53), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
