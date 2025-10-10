import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors
  static const Color primaryBackground = Color(0xFF181818);
  static const Color primaryText = Color(0xFFF7F7F7);
  static const Color primaryAction = Color(0xFFFF5722);
  static const Color secondaryAction = Color(0xFF673AB7);
  static const Color highlight = Color(0xFFFFEB3B);

  // P2P Mode Colors
  static const Color p2pPrimary = Color(0xFF9C27B0);    // Material Purple 500
  static const Color p2pSecondary = Color(0xFF673AB7);  // Deep Purple 500

  // Glassmorphism Colors
  static const Color glassBackground = Color(0x20FFFFFF);
  static const Color glassBorder = Color(0x30FFFFFF);
  static const Color glassHighlight = Color(0x40FFFFFF);

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Surface Colors
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceMedium = Color(0xFF2A2A2A);
  static const Color surfaceLight = Color(0xFF3A3A3A);

  // Text Colors
  static const Color textPrimary = primaryText;
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF707070);
  static const Color textDisabled = Color(0xFF4A4A4A);

  // Shadow Colors
  static const Color shadowLight = Color(0x20000000);
  static const Color shadowMedium = Color(0x40000000);
  static const Color shadowDark = Color(0x60000000);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryAction, secondaryAction],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [p2pPrimary, p2pSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient p2pGradient = LinearGradient(
    colors: [p2pPrimary, p2pSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [glassBackground, Color(0x10FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surfaceDark, surfaceMedium],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}