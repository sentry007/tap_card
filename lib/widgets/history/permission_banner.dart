/// Contact Permission Banner Widget
///
/// Displays a glassmorphic banner prompting the user to grant contacts permission
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../core/constants/app_constants.dart';

/// Banner shown when contacts permission is not granted
class ContactPermissionBanner extends StatelessWidget {
  final VoidCallback onAllowAccess;
  final double statusBarHeight;

  const ContactPermissionBanner({
    super.key,
    required this.onAllowAccess,
    required this.statusBarHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: statusBarHeight + 80 + 36 + AppSpacing.xs + AppSpacing.md,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppColors.primaryAction.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      CupertinoIcons.person_2_square_stack,
                      color: AppColors.primaryAction,
                      size: 24,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Enable Contact Scanning',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Atlas Linq can detect contacts you\'ve received by scanning your device contacts for Atlas Linq URLs.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: AppColors.primaryAction,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    onPressed: onAllowAccess,
                    child: const Text(
                      'Allow Access to Contacts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
