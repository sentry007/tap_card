import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../services/nfc_service.dart';
import '../../core/constants/app_constants.dart';
import '../glassmorphic_dialog.dart';
import '../../utils/snackbar_helper.dart';

/// NFC Helpers
///
/// Collection of helper functions for NFC-related dialogs and snackbars.
/// This keeps the HomeScreen cleaner by centralizing UI feedback.
class NfcHelpers {
  /// Show NFC setup dialog prompting user to enable NFC
  static void showNfcSetupDialog(BuildContext context, VoidCallback onNfcEnabled) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.primaryAction.withValues(alpha: 0.3),
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
                        CupertinoIcons.antenna_radiowaves_left_right,
                        color: AppColors.primaryAction,
                        size: 24,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Enable NFC',
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
                    'NFC is required to share your contact card. Please enable NFC in your device settings to continue.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
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
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openNfcSettings(context, onNfcEnabled);
                      },
                      child: const Text(
                        'Open Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show NFC scanning dialog during active NFC session
  static void showNfcScanningDialog(
    BuildContext context,
    VoidCallback onCancel,
  ) {
    GlassmorphicDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryAction.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          CupertinoIcons.antenna_radiowaves_left_right,
          color: AppColors.primaryAction,
          size: 32,
        ),
      ),
      title: 'NFC Scanning...',
      content:
          'Bring your phone close to:\n• Another NFC-enabled phone or device\n• An NFC tag to write your profile\n\nKeep devices within 4cm of each other.',
      actions: [
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            await NFCService.cancelSession('User cancelled');
            onCancel();
          },
        ),
      ],
    );
  }

  /// Show NFC manual setup instructions dialog
  static void showNfcInstructionsDialog(
    BuildContext context,
    VoidCallback onCheckAgain,
  ) {
    GlassmorphicDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryAction.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          CupertinoIcons.settings,
          color: AppColors.primaryAction,
          size: 32,
        ),
      ),
      title: 'Enable NFC Manually',
      content:
          'To enable NFC:\n\n1. Go to Settings\n2. Find "Connections" or "Wireless & Networks"\n3. Look for "NFC" and turn it on\n4. Come back and check again',
      actions: [
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        DialogAction.primary(
          text: 'Check Again',
          onPressed: onCheckAgain,
        ),
      ],
    );
  }

  /// Open NFC settings
  static Future<void> _openNfcSettings(
    BuildContext context,
    VoidCallback onNfcEnabled,
  ) async {
    try {
      // Try to open NFC settings using app_settings
      await _tryOpenNfcSettings();

      // Add a delay to give user time to toggle NFC
      await Future.delayed(const Duration(milliseconds: 500));

      // After user returns from settings, refresh NFC status
      if (context.mounted) {
        final nfcAvailable = await NFCService.initialize();

        // Show result based on NFC state
        if (nfcAvailable) {
          showSuccessMessage(
            context,
            'NFC is now enabled! You can share your card.',
          );
          onNfcEnabled();
        } else {
          showInfoMessage(
            context,
            'Please enable NFC in settings to use tap-to-share features.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening NFC settings: $e');
      if (context.mounted) {
        showErrorMessage(
          context,
          'Could not open settings. Please enable NFC manually.',
        );
      }
    }
  }

  static Future<void> _tryOpenNfcSettings() async {
    // Open app settings or NFC-specific settings
    // Note: On Android, AppSettings.openAppSettings() opens the app settings page
    // Users can then navigate to NFC settings from there
    // iOS doesn't support NFC settings programmatically
    await AppSettings.openAppSettings();
  }

  /// Check NFC status again after user attempts to enable it
  static Future<void> checkNfcStatusAgain(BuildContext context) async {
    try {
      // Close the current dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Show loading message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAction.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryAction.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Checking NFC status...'),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh NFC status
        final nfcAvailable = await NFCService.initialize();

        // Show result
        if (nfcAvailable) {
          showSuccessMessage(
            context,
            'Great! NFC is now enabled. You can share your card.',
          );
        } else {
          showErrorMessage(
            context,
            'NFC is still disabled. Please enable it in your device settings.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking NFC status: $e');
      if (context.mounted) {
        showErrorMessage(
          context,
          'Failed to check NFC status. Please try again.',
        );
      }
    }
  }

  /// Show success snackbar with glassmorphic design
  static void showSuccessMessage(BuildContext context, String message) {
    SnackbarHelper.showSuccess(
      context,
      message: message,
      icon: CupertinoIcons.check_mark_circled_solid,
      duration: const Duration(seconds: 3),
    );
  }

  /// Show error snackbar with glassmorphic design
  static void showErrorMessage(BuildContext context, String message) {
    SnackbarHelper.showError(
      context,
      message: message,
      icon: CupertinoIcons.exclamationmark_circle_fill,
      duration: const Duration(seconds: 4),
    );
  }

  /// Show info snackbar with glassmorphic design
  static void showInfoMessage(BuildContext context, String message) {
    SnackbarHelper.showInfo(
      context,
      message: message,
      icon: CupertinoIcons.info_circle_fill,
      duration: const Duration(seconds: 3),
    );
  }
}
