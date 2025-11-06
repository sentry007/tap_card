import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../../theme/theme.dart';

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

    return Padding(
      padding: EdgeInsets.only(
        top: statusBarHeight + 16,
        left: 16,
        right: 16,
      ),
      child: SizedBox(
        height: 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Leading widget (e.g., back button)
                    if (leading != null) leading!,
                    if (leading != null) const SizedBox(width: 8),

                    const Spacer(),

                    // Title widget
                    if (title != null) title!,

                    const Spacer(),

                    // Trailing widget (e.g., settings button)
                    if (trailing != null) const SizedBox(width: 8),
                    if (trailing != null) trailing!,

                    // Balance spacing when no leading/trailing
                    if (leading == null && trailing != null) const SizedBox(width: 40),
                    if (leading != null && trailing == null) const SizedBox(width: 40),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color ?? AppColors.textPrimary,
            size: 20,
            semanticLabel: semanticsLabel,
          ),
        ),
      ),
    );
  }
}
