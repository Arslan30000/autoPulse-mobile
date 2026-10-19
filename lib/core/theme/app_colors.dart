import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF1A303C);
  static const Color surface = Color(0xFF203C49);
  static const Color surfaceSecondary = Color(0xFF274753);
  static const Color surfaceTertiary = Color(0xFF315661);
  static const Color tealSurface = Color(0xFF126576);

  // Accent
  static const Color primary = Color(0xFF00ACC7);
  static const Color primaryDim = Color(0xFF087F94);
  static const Color primaryGlow = Color(0x2200ACC7);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color successDim = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFFB74D);
  static const Color warningDim = Color(0xFFF57C00);
  static const Color danger = Color(0xFFEF5350);
  static const Color dangerDim = Color(0xFFC62828);

  // Text
  static const Color textPrimary = Color(0xFFF3F8FA);
  static const Color textSecondary = Color(0xFFB9CED5);
  static const Color textTertiary = Color(0xFF93B0BC);

  // Borders
  static const Color border = Color(0xFF31515E);
  static const Color borderLight = Color(0xFF476975);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surfaceSecondary, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
