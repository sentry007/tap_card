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
    super.key,
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
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ??
        AppColors.glassBackground.withValues(alpha: opacity);
    final effectiveBorderColor = borderColor ?? AppColors.glassBorder;
    final borderRad = BorderRadius.circular(borderRadius);

    Widget content = Padding(
      key: const Key('glass_card_padding'),
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        key: const Key('glass_card_material'),
        color: Colors.transparent,
        child: InkWell(
          key: const Key('glass_card_inkwell'),
          onTap: enabled ? onTap : null,
          borderRadius: borderRad,
          splashColor: AppColors.primaryAction.withValues(alpha: 0.1),
          highlightColor: AppColors.primaryAction.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }

    return Container(
      key: const Key('glass_card_outer_container'),
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRad,
        boxShadow: shadows ?? [
          const BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
          const BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        key: const Key('glass_card_clip_rrect'),
        borderRadius: borderRad,
        child: BackdropFilter(
          key: const Key('glass_card_backdrop_filter'),
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            key: const Key('glass_card_inner_container'),
            decoration: BoxDecoration(
              color: effectiveBackgroundColor,
              borderRadius: borderRad,
              border: Border.all(
                color: effectiveBorderColor,
                width: borderWidth,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.05),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
            child: content,
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
    super.key,
    required this.child,
    this.type = GlassCardType.normal,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case GlassCardType.normal:
        return GlassCard(
          key: const Key('glass_card_variant_normal'),
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
          key: const Key('glass_card_variant_elevated'),
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          onTap: onTap,
          enabled: enabled,
          blur: 15,
          shadows: const [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.shadowDark,
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
          child: child,
        );
      case GlassCardType.subtle:
        return GlassCard(
          key: const Key('glass_card_variant_subtle'),
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          onTap: onTap,
          enabled: enabled,
          blur: 5,
          opacity: 0.08,
          borderWidth: 0.5,
          shadows: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          child: child,
        );
      case GlassCardType.highlighted:
        return GlassCard(
          key: const Key('glass_card_variant_highlighted'),
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          onTap: onTap,
          enabled: enabled,
          borderColor: AppColors.primaryAction.withValues(alpha: 0.3),
          borderWidth: 1.5,
          shadows: [
            BoxShadow(
              color: AppColors.primaryAction.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            const BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 20,
              offset: Offset(0, 8),
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
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.alignment = Alignment.center,
    this.borderRadius = 12,
    this.blur = 8,
    this.opacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    final borderRad = BorderRadius.circular(borderRadius);

    return Container(
      key: const Key('glass_container_outer'),
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      child: ClipRRect(
        key: const Key('glass_container_clip'),
        borderRadius: borderRad,
        child: BackdropFilter(
          key: const Key('glass_container_backdrop'),
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            key: const Key('glass_container_inner'),
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: borderRad,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
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