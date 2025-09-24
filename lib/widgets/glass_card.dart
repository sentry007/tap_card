import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final bool enabled;
  final double opacity;

  const GlassCard({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(8),
    this.borderRadius = 16,
    this.blur = 10,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.shadows,
    this.onTap,
    this.enabled = true,
    this.opacity = 0.15,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ??
        AppColors.glassBackground.withOpacity(opacity);
    final effectiveBorderColor = borderColor ?? AppColors.glassBorder;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: effectiveBackgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: effectiveBorderColor,
                width: borderWidth,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.05),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onTap : null,
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: AppColors.primaryAction.withOpacity(0.1),
                highlightColor: AppColors.primaryAction.withOpacity(0.05),
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassCardVariant extends StatelessWidget {
  final Widget child;
  final GlassCardType type;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool enabled;

  const GlassCardVariant({
    Key? key,
    required this.child,
    this.type = GlassCardType.normal,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.onTap,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case GlassCardType.normal:
        return GlassCard(
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          onTap: onTap,
          enabled: enabled,
          child: child,
        );
      case GlassCardType.elevated:
        return GlassCard(
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          onTap: onTap,
          enabled: enabled,
          blur: 15,
          shadows: [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.shadowDark,
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
          child: child,
        );
      case GlassCardType.subtle:
        return GlassCard(
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          onTap: onTap,
          enabled: enabled,
          blur: 5,
          opacity: 0.08,
          borderWidth: 0.5,
          shadows: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          child: child,
        );
      case GlassCardType.highlighted:
        return GlassCard(
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          onTap: onTap,
          enabled: enabled,
          borderColor: AppColors.primaryAction.withOpacity(0.3),
          borderWidth: 1.5,
          shadows: [
            BoxShadow(
              color: AppColors.primaryAction.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          child: child,
        );
    }
  }
}

enum GlassCardType {
  normal,
  elevated,
  subtle,
  highlighted,
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry alignment;
  final double borderRadius;
  final double blur;
  final double opacity;

  const GlassContainer({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.alignment = Alignment.center,
    this.borderRadius = 12,
    this.blur = 8,
    this.opacity = 0.1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}