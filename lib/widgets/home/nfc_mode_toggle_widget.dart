import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/theme.dart';
import '../../services/nfc_service.dart';

/// NFC Mode Toggle Widget
///
/// Displays a floating mode indicator showing the current NFC mode (Tag Write or P2P Share).
/// Tappable to open a bottom sheet for switching between modes.
///
/// Features:
/// - Glassmorphic design matching app theme
/// - Mode-specific icons and colors
/// - Bottom sheet mode picker
/// - Haptic feedback on interactions
class NfcModeToggleWidget extends StatelessWidget {
  final NfcMode currentMode;
  final ValueChanged<NfcMode> onModeChanged;

  const NfcModeToggleWidget({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showModePicker(context);
      },
      child: Container(
        key: const Key('home_mode_toggle_container'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.glassBorder.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentMode == NfcMode.tagWrite
                  ? CupertinoIcons.tag_fill
                  : CupertinoIcons.radiowaves_right,
              color: currentMode == NfcMode.tagWrite
                  ? AppColors.primaryAction
                  : AppColors.p2pPrimary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              currentMode == NfcMode.tagWrite ? 'Tag Write' : 'P2P Share',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.chevron_down,
              color: AppColors.textTertiary,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  /// Show mode picker bottom sheet
  void _showModePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Select NFC Mode',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.glassBorder.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _ModeToggleOption(
                      icon: CupertinoIcons.tag_fill,
                      title: 'Tag Write',
                      subtitle: 'Write to physical NFC tags',
                      isSelected: currentMode == NfcMode.tagWrite,
                      color: AppColors.primaryAction,
                      onTap: () {
                        Navigator.pop(context);
                        _switchToMode(context, NfcMode.tagWrite);
                      },
                    ),
                    const SizedBox(height: 4),
                    _ModeToggleOption(
                      icon: CupertinoIcons.radiowaves_right,
                      title: 'P2P Share',
                      subtitle: 'Phone-to-phone sharing',
                      isSelected: currentMode == NfcMode.p2pShare,
                      color: AppColors.p2pPrimary,
                      isAvailable: NFCService.isHceSupported,
                      onTap: () {
                        Navigator.pop(context);
                        if (NFCService.isHceSupported) {
                          _switchToMode(context, NfcMode.p2pShare);
                        } else {
                          _showErrorMessage(
                            context,
                            'Phone-to-Phone mode not supported on this device',
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  /// Switch to a new NFC mode
  void _switchToMode(BuildContext context, NfcMode newMode) {
    if (currentMode == newMode) return;

    onModeChanged(newMode);
    NFCService.switchMode(newMode);
    HapticFeedback.lightImpact();

    final modeName = newMode == NfcMode.tagWrite ? 'Tag Write' : 'Phone-to-Phone';
    _showInfoMessage(context, 'Switched to $modeName mode');
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle_fill, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.info_circle_fill, color: AppColors.info),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.info.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Individual mode toggle option widget
class _ModeToggleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final bool isAvailable;

  const _ModeToggleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.isAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.surfaceMedium.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isAvailable ? AppColors.textTertiary : AppColors.textDisabled),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isAvailable ? AppColors.textPrimary : AppColors.textDisabled),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
