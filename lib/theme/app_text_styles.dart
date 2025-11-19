import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../utils/responsive_helper.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Roboto';

  // BACKWARD COMPATIBILITY: Static const fields for existing code
  // These will work but won't be responsive. Gradually migrate to responsive versions.
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

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.3,
    letterSpacing: 0.4,
  );

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

  // RESPONSIVE TEXT STYLES - Use these for new code or when refactoring
  // These scale based on screen size for better cross-device support

  /// Responsive H1 heading style
  static TextStyle responsiveH1(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 24),
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      height: 1.2,
      letterSpacing: -0.5,
    );
  }

  /// Responsive H2 heading style
  static TextStyle responsiveH2(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 20),
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      height: 1.2,
      letterSpacing: -0.25,
    );
  }

  /// Responsive H3 heading style
  static TextStyle responsiveH3(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 16),
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      height: 1.3,
      letterSpacing: 0,
    );
  }

  /// Responsive body text style
  static TextStyle responsiveBody(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 14),
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1.4,
      letterSpacing: 0.25,
    );
  }

  /// Responsive body secondary text style
  static TextStyle responsiveBodySecondary(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 14),
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.4,
      letterSpacing: 0.25,
    );
  }

  /// Responsive caption text style
  static TextStyle responsiveCaption(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 12),
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.3,
      letterSpacing: 0.4,
    );
  }

  /// Responsive large button text style
  static TextStyle responsiveButtonLarge(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 16),
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      height: 1.0,
      letterSpacing: 0.5,
    );
  }

  /// Responsive medium button text style
  static TextStyle responsiveButtonMedium(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 14),
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      height: 1.0,
      letterSpacing: 0.25,
    );
  }

  /// Responsive small button text style
  static TextStyle responsiveButtonSmall(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 12),
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      height: 1.0,
      letterSpacing: 0.5,
    );
  }

  /// Responsive overline text style
  static TextStyle responsiveOverline(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 10),
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiary,
      height: 1.6,
      letterSpacing: 1.5,
    );
  }

  /// Responsive subtitle text style
  static TextStyle responsiveSubtitle(BuildContext context) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: ResponsiveHelper.fontSize(context, 16),
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.5,
      letterSpacing: 0.15,
    );
  }

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