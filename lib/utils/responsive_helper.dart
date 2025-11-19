import 'package:flutter/material.dart';

/// Responsive Helper Utility
///
/// Provides utilities for responsive sizing across different screen sizes.
/// Uses a baseline of 375px width (iPhone standard) for calculations.
///
/// Screen Size Breakpoints:
/// - Small: < 360px (iPhone SE, small Android)
/// - Medium: 360px - 414px (Most phones, including OnePlus 8)
/// - Large: > 414px (Large phones, tablets)
class ResponsiveHelper {
  ResponsiveHelper._(); // Private constructor to prevent instantiation

  // Baseline dimensions (iPhone standard)
  static const double _baselineWidth = 375.0;
  static const double _baselineHeight = 667.0;

  // Screen size breakpoints
  static const double _smallBreakpoint = 360.0;
  static const double _largeBreakpoint = 414.0;

  /// Get screen size category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < _smallBreakpoint) return ScreenSize.small;
    if (width < _largeBreakpoint) return ScreenSize.medium;
    return ScreenSize.large;
  }

  /// Get responsive width based on percentage of screen width
  ///
  /// Example:
  /// ```dart
  /// width: ResponsiveHelper.widthPercent(context, 0.8), // 80% of screen width
  /// ```
  static double widthPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.width * percent;
  }

  /// Get responsive height based on percentage of screen height
  ///
  /// Example:
  /// ```dart
  /// height: ResponsiveHelper.heightPercent(context, 0.1), // 10% of screen height
  /// ```
  static double heightPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.height * percent;
  }

  /// Get responsive width with min/max constraints
  ///
  /// Example:
  /// ```dart
  /// width: ResponsiveHelper.responsiveWidth(
  ///   context,
  ///   percent: 0.8,
  ///   min: 200,
  ///   max: 400,
  /// ),
  /// ```
  static double responsiveWidth(
    BuildContext context, {
    required double percent,
    double? min,
    double? max,
  }) {
    final width = MediaQuery.of(context).size.width * percent;
    if (min != null && width < min) return min;
    if (max != null && width > max) return max;
    return width;
  }

  /// Get responsive height with min/max constraints
  ///
  /// Example:
  /// ```dart
  /// height: ResponsiveHelper.responsiveHeight(
  ///   context,
  ///   percent: 0.08,
  ///   min: 60,
  ///   max: 80,
  /// ),
  /// ```
  static double responsiveHeight(
    BuildContext context, {
    required double percent,
    double? min,
    double? max,
  }) {
    final height = MediaQuery.of(context).size.height * percent;
    if (min != null && height < min) return min;
    if (max != null && height > max) return max;
    return height;
  }

  /// Get responsive font size based on screen width
  ///
  /// Scales font size proportionally to screen width using baseline of 375px.
  /// Includes min/max constraints to prevent extreme sizes.
  ///
  /// Example:
  /// ```dart
  /// fontSize: ResponsiveHelper.fontSize(context, 16), // Responsive 16px
  /// ```
  static double fontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / _baselineWidth;

    // Clamp scale factor between 0.85 and 1.15 to prevent extreme sizes
    final clampedScale = scaleFactor.clamp(0.85, 1.15);

    return baseSize * clampedScale;
  }

  /// Get responsive font size with custom min/max constraints
  ///
  /// Example:
  /// ```dart
  /// fontSize: ResponsiveHelper.fontSizeWithConstraints(
  ///   context,
  ///   baseSize: 24,
  ///   min: 20,
  ///   max: 28,
  /// ),
  /// ```
  static double fontSizeWithConstraints(
    BuildContext context, {
    required double baseSize,
    double? min,
    double? max,
  }) {
    final responsive = fontSize(context, baseSize);
    if (min != null && responsive < min) return min;
    if (max != null && responsive > max) return max;
    return responsive;
  }

  /// Get responsive spacing value
  ///
  /// Scales spacing based on screen width, useful for margins and padding.
  ///
  /// Example:
  /// ```dart
  /// padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
  /// ```
  static double spacing(BuildContext context, double baseSpacing) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / _baselineWidth;

    // More conservative scaling for spacing (0.9 - 1.1)
    final clampedScale = scaleFactor.clamp(0.9, 1.1);

    return baseSpacing * clampedScale;
  }

  /// Get responsive icon size
  ///
  /// Example:
  /// ```dart
  /// size: ResponsiveHelper.iconSize(context, 24),
  /// ```
  static double iconSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / _baselineWidth;

    // Icon scaling (0.9 - 1.1)
    final clampedScale = scaleFactor.clamp(0.9, 1.1);

    return baseSize * clampedScale;
  }

  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Check if screen is small (< 360px)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < _smallBreakpoint;
  }

  /// Check if screen is medium (360px - 414px)
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= _smallBreakpoint && width < _largeBreakpoint;
  }

  /// Check if screen is large (> 414px)
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= _largeBreakpoint;
  }

  /// Get adaptive value based on screen size
  ///
  /// Example:
  /// ```dart
  /// final height = ResponsiveHelper.adaptive(
  ///   context,
  ///   small: 60.0,
  ///   medium: 70.0,
  ///   large: 80.0,
  /// );
  /// ```
  static T adaptive<T>(
    BuildContext context, {
    required T small,
    required T medium,
    required T large,
  }) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return small;
      case ScreenSize.medium:
        return medium;
      case ScreenSize.large:
        return large;
    }
  }

  /// Get responsive border radius
  ///
  /// Example:
  /// ```dart
  /// borderRadius: BorderRadius.circular(
  ///   ResponsiveHelper.borderRadius(context, 16),
  /// ),
  /// ```
  static double borderRadius(BuildContext context, double baseRadius) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / _baselineWidth;

    // Conservative scaling for border radius (0.95 - 1.05)
    final clampedScale = scaleFactor.clamp(0.95, 1.05);

    return baseRadius * clampedScale;
  }

  /// Get responsive size (maintains aspect ratio)
  ///
  /// Example:
  /// ```dart
  /// final size = ResponsiveHelper.responsiveSize(
  ///   context,
  ///   baseWidth: 240,
  ///   baseHeight: 120,
  ///   widthPercent: 0.6,
  ///   minWidth: 200,
  ///   maxWidth: 280,
  /// );
  /// // Returns Size object
  /// ```
  static Size responsiveSize(
    BuildContext context, {
    required double baseWidth,
    required double baseHeight,
    double? widthPercent,
    double? heightPercent,
    double? minWidth,
    double? maxWidth,
    double? minHeight,
    double? maxHeight,
  }) {
    double width;
    double height;

    if (widthPercent != null) {
      width = responsiveWidth(
        context,
        percent: widthPercent,
        min: minWidth,
        max: maxWidth,
      );
      // Maintain aspect ratio
      height = width * (baseHeight / baseWidth);
      if (minHeight != null && height < minHeight) {
        height = minHeight;
        width = height * (baseWidth / baseHeight);
      }
      if (maxHeight != null && height > maxHeight) {
        height = maxHeight;
        width = height * (baseWidth / baseHeight);
      }
    } else if (heightPercent != null) {
      height = responsiveHeight(
        context,
        percent: heightPercent,
        min: minHeight,
        max: maxHeight,
      );
      // Maintain aspect ratio
      width = height * (baseWidth / baseHeight);
      if (minWidth != null && width < minWidth) {
        width = minWidth;
        height = width * (baseHeight / baseWidth);
      }
      if (maxWidth != null && width > maxWidth) {
        width = maxWidth;
        height = width * (baseHeight / baseWidth);
      }
    } else {
      // Fallback to base sizes
      width = baseWidth;
      height = baseHeight;
    }

    return Size(width, height);
  }
}

/// Screen size categories
enum ScreenSize {
  small, // < 360px
  medium, // 360px - 414px
  large, // > 414px
}
