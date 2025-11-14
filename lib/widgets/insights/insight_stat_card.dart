/// Insight Stat Card Widget
///
/// Displays a single statistic with icon, value, label, and optional subtitle
/// Used in the overview section of insights screen
library;

import 'package:flutter/material.dart';
import 'dart:ui';

import '../../theme/theme.dart';

class InsightStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final bool isSmallText;

  const InsightStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
    this.isSmallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Icon
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              // Right: Value + Label + Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: isSmallText
                          ? AppTextStyles.h3.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            )
                          : AppTextStyles.h1.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
