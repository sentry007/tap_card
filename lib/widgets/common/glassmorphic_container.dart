/// Reusable Glassmorphic Container Widget
///
/// A beautiful glassmorphic container with customizable blur, opacity, border,
/// and shadow effects. Used throughout the app for consistent UI styling.
///
/// Example usage:
/// ```dart
/// GlassmorphicContainer(
///   child: Text('Hello'),
///   borderRadius: 16,
///   blur: 10,
/// )
/// ```
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../core/constants/app_constants.dart';

/// A container with glassmorphic effect (blur + semi-transparent background)
class GlassmorphicContainer extends StatelessWidget {
  /// The child widget to display inside the container
  final Widget child;

  /// Border radius for the container (default: 16)
  final double borderRadius;

  /// Background blur intensity (default: 10)
  final double blur;

  /// Background color opacity (default: 0.1)
  final double backgroundOpacity;

  /// Border color opacity (default: 0.2)
  final double borderOpacity;

  /// Border width (default: 1)
  final double borderWidth;

  /// Whether to show shadow (default: true)
  final bool showShadow;

  /// Custom background color (default: white)
  final Color? backgroundColor;

  /// Custom border color (default: white)
  final Color? borderColor;

  /// Padding inside the container
  final EdgeInsetsGeometry? padding;

  /// Margin outside the container
  final EdgeInsetsGeometry? margin;

  /// Container width
  final double? width;

  /// Container height
  final double? height;

  /// Widget key for testing
  final Key? containerKey;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.lg,
    this.blur = GlassConstants.blurDefault,
    this.backgroundOpacity = GlassConstants.backgroundOpacityLight,
    this.borderOpacity = GlassConstants.borderOpacityMedium,
    this.borderWidth = 1.0,
    this.showShadow = true,
    this.backgroundColor,
    this.borderColor,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.containerKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            key: containerKey,
            padding: padding,
            decoration: BoxDecoration(
              color: (backgroundColor ?? Colors.white).withOpacity(backgroundOpacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: (borderColor ?? Colors.white).withOpacity(borderOpacity),
                width: borderWidth,
              ),
              boxShadow: showShadow
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A glassmorphic card with preset styling for common use cases
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isSelected;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.isSelected = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final container = GlassmorphicContainer(
      borderRadius: AppRadius.lg,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      margin: margin,
      width: width,
      height: height,
      borderColor: isSelected ? AppColors.primaryAction : null,
      borderWidth: isSelected ? 2 : 1,
      borderOpacity: isSelected ? 1.0 : GlassConstants.borderOpacityMedium,
      showShadow: isSelected,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: container,
        ),
      );
    }

    return container;
  }
}

/// A glassmorphic button with preset styling
class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool isDestructive;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      borderRadius: AppRadius.button,
      borderColor: isDestructive ? AppColors.error : AppColors.primaryAction,
      borderOpacity: 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Center(child: child),
        ),
      ),
    );
  }
}
