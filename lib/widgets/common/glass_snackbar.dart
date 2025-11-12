import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../theme/theme.dart';

enum GlassSnackBarType { success, error, warning, info }

class GlassSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    GlassSnackBarType type = GlassSnackBarType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    final Color baseColor = _colorFor(type);
    final IconData resolvedIcon = icon ?? _iconFor(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: baseColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(resolvedIcon, color: baseColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  static Color _colorFor(GlassSnackBarType type) {
    switch (type) {
      case GlassSnackBarType.success:
        return AppColors.success;
      case GlassSnackBarType.error:
        return AppColors.error;
      case GlassSnackBarType.warning:
        return AppColors.warning;
      case GlassSnackBarType.info:
        return AppColors.info;
    }
  }

  static IconData _iconFor(GlassSnackBarType type) {
    switch (type) {
      case GlassSnackBarType.success:
        return CupertinoIcons.checkmark_circle;
      case GlassSnackBarType.error:
        return CupertinoIcons.exclamationmark_circle;
      case GlassSnackBarType.warning:
        return CupertinoIcons.exclamationmark_triangle;
      case GlassSnackBarType.info:
        return CupertinoIcons.info;
    }
  }
}














