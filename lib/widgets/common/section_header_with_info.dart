import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../theme/theme.dart';

/// Section header with optional info button
///
/// Displays a section title with an optional glassmorphic info button
/// that shows a tooltip/dialog with explanatory text when tapped.
///
/// Usage:
/// ```dart
/// SectionHeaderWithInfo(
///   title: 'Recent Connections',
///   infoText: 'People who have shared their digital cards with you.',
/// )
/// ```
class SectionHeaderWithInfo extends StatelessWidget {
  final String title;
  final String? infoText;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  const SectionHeaderWithInfo({
    super.key,
    required this.title,
    this.infoText,
    this.style,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? AppTextStyles.h3.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: textStyle,
          ),
          if (infoText != null) ...[
            const SizedBox(width: 8),
            _InfoButton(infoText: infoText!),
          ],
        ],
      ),
    );
  }
}

/// Glassmorphic info button widget
class _InfoButton extends StatelessWidget {
  final String infoText;

  const _InfoButton({required this.infoText});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showInfoDialog(context);
      },
      child: Icon(
        CupertinoIcons.info_circle,
        size: 18,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryAction.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.info_circle_fill,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Info text
                  Text(
                    infoText,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primaryAction.withValues(alpha: 0.3),
                                AppColors.secondaryAction.withValues(alpha: 0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryAction.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Got it',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
