/// Insight Info Button Widget
///
/// Displays a small info icon that shows a dialog with explanation text
/// when tapped. Used throughout the insights screen to provide context.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../theme/theme.dart';

class InsightInfoButton extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const InsightInfoButton({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.info_outline,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showInfoDialog(context);
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.info.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppColors.info,
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InfoDialog(
        title: title,
        description: description,
        icon: icon,
      ),
    );
  }
}

class _InfoDialog extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _InfoDialog({
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
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceDark.withValues(alpha: 0.95),
                  AppColors.surfaceDark.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.glassBorder,
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
