import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../../theme/theme.dart';
import '../../utils/responsive_helper.dart';
import '../../core/constants/app_constants.dart';

/// Reusable Glass App Bar Widget
///
/// A glassmorphic app bar with blur effect, used across multiple screens
class GlassAppBar extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? trailing;

  const GlassAppBar({
    super.key,
    this.leading,
    this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Responsive dimensions
    final appBarHeight = AppSpacing.responsiveAppBarHeight(context);
    final topPadding = AppSpacing.responsiveMd(context);
    final horizontalPadding = AppSpacing.responsiveMd(context);
    final borderRadius = ResponsiveHelper.borderRadius(context, 20);
    final contentPadding = AppSpacing.responsiveMd(context);
    final spacing = AppSpacing.responsiveSm(context);

    return Padding(
      padding: EdgeInsets.only(
        top: statusBarHeight + topPadding,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      child: SizedBox(
        height: appBarHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: contentPadding),
                child: Row(
                  children: [
                    // Leading widget (e.g., back button)
                    if (leading != null) leading!,
                    if (leading != null) SizedBox(width: spacing),

                    const Spacer(),

                    // Title widget
                    if (title != null) title!,

                    const Spacer(),

                    // Trailing widget (e.g., settings button)
                    if (trailing != null) SizedBox(width: spacing),
                    if (trailing != null) trailing!,

                    // Balance spacing when no leading/trailing
                    if (leading == null && trailing != null) SizedBox(width: ComponentSizes.responsiveIconMd(context) + spacing),
                    if (leading != null && trailing == null) SizedBox(width: ComponentSizes.responsiveIconMd(context) + spacing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass Icon Button for use in GlassAppBar
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticsLabel;
  final Color? color;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticsLabel,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = ComponentSizes.responsiveIconMd(context) + AppSpacing.responsiveMd(context);
    final iconSize = ComponentSizes.responsiveIconSm(context);
    final borderRadius = ResponsiveHelper.borderRadius(context, 12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            icon,
            color: color ?? AppColors.textPrimary,
            size: iconSize,
            semanticLabel: semanticsLabel,
          ),
        ),
      ),
    );
  }
}
