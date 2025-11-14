/// App Info Button - Unified Component
///
/// Simple icon-only button that displays an info dialog when tapped.
/// Used consistently across the entire app for contextual help.
///
/// Features:
/// - Clean icon-only design (no background box)
/// - Simple glassmorphism modal
/// - Haptic feedback
/// - Customizable icon and colors
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../theme/theme.dart';

/// Unified info button widget used throughout the app
class AppInfoButton extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? iconColor;
  final double iconSize;

  const AppInfoButton({
    super.key,
    required this.title,
    required this.description,
    this.icon = CupertinoIcons.info_circle,
    this.iconColor,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showInfoDialog(context);
      },
      child: Icon(
        icon,
        size: iconSize,
        color: iconColor ?? Colors.white.withValues(alpha: 0.6),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => _AppInfoDialog(
        title: title,
        description: description,
        icon: icon,
      ),
    );
  }
}

/// Simple glassmorphism info dialog
class _AppInfoDialog extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _AppInfoDialog({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceDark.withValues(alpha: 0.85),
                  AppColors.surfaceDark.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.glassBorder.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  title,
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  description,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Got it',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
