import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF121821);
  static const Color surfaceSecondary = Color(0xFF18212C);
  static const Color surfaceTertiary = Color(0xFF1E2A3A);

  // Accent
  static const Color primary = Color(0xFF00D4FF);
  static const Color primaryDim = Color(0xFF0098B8);
  static const Color primaryGlow = Color(0x3300D4FF);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color successDim = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFFB74D);
  static const Color warningDim = Color(0xFFF57C00);
  static const Color danger = Color(0xFFEF5350);
  static const Color dangerDim = Color(0xFFC62828);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E99A8);
  static const Color textTertiary = Color(0xFF5A6577);

  // Borders
  static const Color border = Color(0xFF1E2A3A);
  static const Color borderLight = Color(0xFF2A3544);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0098B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF121821), Color(0xFF18212C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF18212C), Color(0xFF121821)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
