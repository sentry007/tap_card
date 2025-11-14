/// Snackbar Helper Utility
///
/// Provides reusable glassmorphic snackbar components for consistent
/// user feedback throughout the app.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Types of snackbar messages
enum SnackbarType {
  success,
  error,
  warning,
  info,
}

/// Snackbar helper class for showing consistent glassmorphic notifications
class SnackbarHelper {
  /// Show a glassmorphic snackbar with custom styling
  ///
  /// [context] - BuildContext for showing the snackbar
  /// [message] - Message text to display
  /// [icon] - Icon to show (default based on type)
  /// [type] - Type of snackbar (determines color scheme)
  /// [duration] - How long to show the snackbar (default 2 seconds)
  /// [action] - Optional action button
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    final colorScheme = _getColorScheme(type);
    final defaultIcon = _getDefaultIcon(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon ?? defaultIcon, color: colorScheme),
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
        action: action,
      ),
    );
  }

  /// Show a success snackbar
  static void showSuccess(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      icon: icon,
      type: SnackbarType.success,
      duration: duration,
    );
  }

  /// Show an error snackbar
  static void showError(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      icon: icon,
      type: SnackbarType.error,
      duration: duration,
    );
  }

  /// Show a warning snackbar
  static void showWarning(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      icon: icon,
      type: SnackbarType.warning,
      duration: duration,
    );
  }

  /// Show an info snackbar
  static void showInfo(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      icon: icon,
      type: SnackbarType.info,
      duration: duration,
    );
  }

  /// Get color scheme based on snackbar type
  static Color _getColorScheme(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return AppColors.success;
      case SnackbarType.error:
        return AppColors.error;
      case SnackbarType.warning:
        return AppColors.warning;
      case SnackbarType.info:
        return Colors.blueAccent;
    }
  }

  /// Get default icon based on snackbar type
  static IconData _getDefaultIcon(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return CupertinoIcons.checkmark_circle;
      case SnackbarType.error:
        return CupertinoIcons.exclamationmark_circle;
      case SnackbarType.warning:
        return CupertinoIcons.exclamationmark_triangle;
      case SnackbarType.info:
        return CupertinoIcons.info_circle;
    }
  }
}
