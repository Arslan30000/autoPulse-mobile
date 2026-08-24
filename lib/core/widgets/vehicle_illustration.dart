import 'package:flutter/material.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/models/health.dart';

class VehicleIllustration extends StatelessWidget {
  final List<SystemHealth>? systems;
  final double height;

  const VehicleIllustration({
    super.key,
    this.systems,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _VehiclePainter(systems: systems),
      ),
    );
  }
}

class _VehiclePainter extends CustomPainter {
  final List<SystemHealth>? systems;

  _VehiclePainter({this.systems});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final carWidth = size.width * 0.35;
    final carHeight = size.height * 0.85;

    // Car body outline
    final bodyPaint = Paint()
      ..color = AppColors.surfaceTertiary
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Main body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, centerY), width: carWidth, height: carHeight),
      const Radius.circular(20),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, outlinePaint);

    // Windshield (front)
    final windshieldPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final windshieldRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY - carHeight * 0.25),
        width: carWidth * 0.7,
        height: carHeight * 0.18,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(windshieldRect, windshieldPaint);
    canvas.drawRRect(windshieldRect, outlinePaint);

    // Rear windshield
    final rearRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY + carHeight * 0.28),
        width: carWidth * 0.65,
        height: carHeight * 0.12,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(rearRect, windshieldPaint);
    canvas.drawRRect(rearRect, outlinePaint);

    // Wheels
    final wheelPaint = Paint()
      ..color = AppColors.surfaceTertiary.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    final wheelOutline = Paint()
      ..color = AppColors.primary.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final wheelWidth = carWidth * 0.22;
    final wheelHeight = carHeight * 0.12;
    final wheelOffsetX = carWidth / 2 + wheelWidth * 0.4;

    // Front wheels
    for (final side in [-1.0, 1.0]) {
      final wheelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX + side * wheelOffsetX, centerY - carHeight * 0.28),
          width: wheelWidth,
          height: wheelHeight,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(wheelRect, wheelPaint);
      canvas.drawRRect(wheelRect, wheelOutline);
    }

    // Rear wheels
    for (final side in [-1.0, 1.0]) {
      final wheelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX + side * wheelOffsetX, centerY + carHeight * 0.28),
          width: wheelWidth,
          height: wheelHeight,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(wheelRect, wheelPaint);
      canvas.drawRRect(wheelRect, wheelOutline);
    }

    // Center line
    final linePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(centerX, centerY - carHeight * 0.35),
      Offset(centerX, centerY + carHeight * 0.35),
      linePaint,
    );

    // System indicator dots
    if (systems != null) {
      final dotPositions = <String, Offset>{
        'Engine': Offset(centerX, centerY - carHeight * 0.15),
        'Cooling': Offset(centerX - carWidth * 0.2, centerY - carHeight * 0.22),
        'Air Intake': Offset(centerX + carWidth * 0.2, centerY - carHeight * 0.18),
        'Sensors': Offset(centerX - carWidth * 0.15, centerY + carHeight * 0.05),
        'Electrical': Offset(centerX, centerY + carHeight * 0.05),
        'Transmission': Offset(centerX, centerY + carHeight * 0.22),
      };

      for (final system in systems!) {
        final pos = dotPositions[system.name];
        if (pos == null) continue;

        Color dotColor;
        switch (system.status) {
          case SystemStatus.normal:
            dotColor = AppColors.success;
            break;
          case SystemStatus.attention:
            dotColor = AppColors.warning;
            break;
          case SystemStatus.warning:
            dotColor = AppColors.warningDim;
            break;
          case SystemStatus.critical:
            dotColor = AppColors.danger;
            break;
        }

        // Glow
        canvas.drawCircle(
          pos,
          8,
          Paint()..color = dotColor.withOpacity(0.2),
        );
        // Dot
        canvas.drawCircle(
          pos,
          4,
          Paint()..color = dotColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter oldDelegate) {
    return oldDelegate.systems != systems;
  }
}
