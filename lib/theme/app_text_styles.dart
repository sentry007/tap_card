import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Roboto';

  // Headings
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.25,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: 0,
  );

  // Body Text
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.4,
    letterSpacing: 0.25,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: 0.25,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.3,
    letterSpacing: 0.4,
  );

  // Button Text
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.0,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.0,
    letterSpacing: 0.25,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.0,
    letterSpacing: 0.5,
  );

  // Special Styles
  static const TextStyle overline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    height: 1.6,
    letterSpacing: 1.5,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
    letterSpacing: 0.15,
  );

  // Color Variants
  static TextStyle h1Primary = h1.copyWith(color: AppColors.primaryAction);
  static TextStyle h1Secondary = h1.copyWith(color: AppColors.secondaryAction);
  static TextStyle h1Highlight = h1.copyWith(color: AppColors.highlight);

  static TextStyle h2Primary = h2.copyWith(color: AppColors.primaryAction);
  static TextStyle h2Secondary = h2.copyWith(color: AppColors.secondaryAction);
  static TextStyle h2Highlight = h2.copyWith(color: AppColors.highlight);

  static TextStyle bodyPrimary = body.copyWith(color: AppColors.primaryAction);
  static TextStyle bodySecondaryAction = body.copyWith(color: AppColors.secondaryAction);
  static TextStyle bodyHighlight = body.copyWith(color: AppColors.highlight);

  // Error and Success Variants
  static TextStyle bodyError = body.copyWith(color: AppColors.error);
  static TextStyle bodySuccess = body.copyWith(color: AppColors.success);
  static TextStyle bodyWarning = body.copyWith(color: AppColors.warning);
  static TextStyle bodyInfo = body.copyWith(color: AppColors.info);
}