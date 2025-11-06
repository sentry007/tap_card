import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../services/nfc_service.dart';

/// Five-state NFC FAB system for comprehensive user feedback
enum NfcFabState {
  inactive, // Dull white icon, no animations
  active, // Glowing white, breathing + ripple
  writing, // Loading spinner during NFC write
  success, // Green checkmark after successful write
  error // Red X after failed write
}

/// Hero NFC FAB Widget
///
/// A beautifully animated floating action button for NFC operations.
/// Supports two modes: Tag Write and P2P Share.
///
/// Features:
/// - 5-state system (inactive, active, writing, success, error)
/// - Breathing pulse animation
/// - Ripple waves when NFC device detected
/// - Dynamic colors based on state and mode
/// - Smooth transitions between states
class NfcFabWidget extends StatefulWidget {
  final NfcFabState state;
  final NfcMode mode;
  final bool nfcAvailable;
  final bool nfcDeviceDetected;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  // Animation controllers passed from parent for coordination
  final Animation<double> fabScale;
  final Animation<double> fabGlow;
  final Animation<double> pulseScale;
  final Animation<double> rippleWave;
  final Animation<double> successScale;

  const NfcFabWidget({
    super.key,
    required this.state,
    required this.mode,
    required this.nfcAvailable,
    required this.nfcDeviceDetected,
    required this.isLoading,
    required this.onTap,
    required this.onLongPress,
    required this.fabScale,
    required this.fabGlow,
    required this.pulseScale,
    required this.rippleWave,
    required this.successScale,
  });

  @override
  State<NfcFabWidget> createState() => _NfcFabWidgetState();
}

class _NfcFabWidgetState extends State<NfcFabWidget> {
  @override
  Widget build(BuildContext context) {
    // Get NFC state colors for dynamic theming
    final nfcColors = _getNfcStateColors();
    final hasDevice = widget.nfcDeviceDetected;

    return Transform.scale(
      scale: widget.fabScale.value * widget.pulseScale.value * (hasDevice ? 1.05 : 1.0),
      child: SizedBox(
        key: const Key('nfc-fab-container'),
        width: 240,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated outer glow effect
            Container(
              key: const Key('nfc-fab-glow'),
              width: 240,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: nfcColors['primary']!.withOpacity(
                      (hasDevice ? widget.fabGlow.value * 1.5 : widget.fabGlow.value)
                          .clamp(0.0, 1.0),
                    ),
                    blurRadius: hasDevice ? 50 : 40,
                    spreadRadius: hasDevice ? 8 : 4,
                  ),
                  BoxShadow(
                    color: nfcColors['secondary']!.withOpacity(
                      (hasDevice ? widget.fabGlow.value : widget.fabGlow.value * 0.7)
                          .clamp(0.0, 1.0),
                    ),
                    blurRadius: hasDevice ? 45 : 35,
                    spreadRadius: hasDevice ? 6 : 2,
                  ),
                ],
              ),
            ),
            // Ripple wave animation matching FAB shape - show when in active state
            if (widget.state == NfcFabState.active)
              ...List.generate(3, (index) {
                final delay = index * 0.3; // Quicker succession
                final progress =
                    (widget.rippleWave.value - delay).clamp(0.0, 1.0);

                // Smooth easing function for more natural animation
                final easedProgress = Curves.easeOut.transform(progress);
                final rippleWidth = 210.0 +
                    (easedProgress * 240.0); // Start closer to FAB width, expand more
                final rippleHeight = 110.0 +
                    (easedProgress * 120.0); // Start closer to FAB height
                final borderRadius = 20.0 +
                    (easedProgress *
                        10.0); // Match FAB shape with slight growth

                // More subtle fade out
                final opacity = (1.0 - easedProgress) * 0.6;

                if (opacity <= 0.0) return const SizedBox.shrink();

                return Container(
                  key: Key('home_nfc_fab_ripple_$index'),
                  width: rippleWidth,
                  height: rippleHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: nfcColors['primary']!.withOpacity(opacity),
                      width: 1.5,
                    ),
                  ),
                );
              }),
            // Main FAB
            Container(
              key: const Key('home_nfc_fab_main'),
              width: 192, // 8px * 24 (doubled width)
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [nfcColors['primary']!, nfcColors['secondary']!],
                ),
                borderRadius:
                    BorderRadius.circular(20), // Smooth square corners
                boxShadow: [
                  BoxShadow(
                    color: nfcColors['primary']!.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: nfcColors['secondary']!.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                key: const Key('home_nfc_fab_material'),
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('home_nfc_fab_inkwell'),
                  onTap: widget.isLoading ? null : widget.onTap,
                  onLongPress: widget.isLoading ? null : widget.onLongPress,
                  borderRadius:
                      BorderRadius.circular(20), // Match container radius
                  child: Center(
                    key: const Key('home_nfc_fab_center'),
                    child: _buildFabContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabContent() {
    // Mode-specific icons
    final IconData modeIcon = widget.mode == NfcMode.tagWrite
        ? CupertinoIcons.arrow_up_arrow_down_square
        : CupertinoIcons.radiowaves_right;

    // Special case: NFC disabled
    if (!widget.nfcAvailable) {
      return Icon(
        modeIcon,
        key: const Key('home_nfc_fab_disabled'),
        color: AppColors.textSecondary, // Gray
        size: 56,
      );
    }

    // FIVE-STATE FAB SYSTEM
    switch (widget.state) {
      case NfcFabState.inactive:
        // Dull white icon, no animations
        return Icon(
          modeIcon,
          key: const Key('home_nfc_fab_inactive'),
          color: Colors.white.withOpacity(0.5), // Dull white
          size: 56,
        );

      case NfcFabState.active:
        // Glowing white icon with breathing animation, NO TEXT
        return ScaleTransition(
          key: const Key('home_nfc_fab_active'),
          scale: widget.pulseScale,
          child: Icon(
            modeIcon,
            color: Colors.white, // Glowing white
            size: 56,
          ),
        );

      case NfcFabState.writing:
        // Loading spinner during NFC write
        return const SizedBox(
          key: Key('home_nfc_fab_writing'),
          width: 32,
          height: 32,
          child: CupertinoActivityIndicator(
            color: Colors.white,
            radius: 16,
          ),
        );

      case NfcFabState.success:
        // Green checkmark with pop animation
        return ScaleTransition(
          key: const Key('home_nfc_fab_success'),
          scale: widget.successScale,
          child: const Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: Colors.greenAccent,
            size: 56,
          ),
        );

      case NfcFabState.error:
        // Red X icon
        return const Icon(
          CupertinoIcons.exclamationmark_circle_fill,
          key: Key('home_nfc_fab_error'),
          color: Colors.redAccent,
          size: 56,
        );
    }
  }

  Map<String, Color> _getNfcStateColors() {
    // Gray gradient ONLY for NFC disabled
    if (!widget.nfcAvailable) {
      return {
        'primary': Colors.grey.shade400,
        'secondary': Colors.grey.shade600,
      };
    }

    // State-based colors when NFC is available
    switch (widget.state) {
      case NfcFabState.inactive:
      case NfcFabState.active:
      case NfcFabState.writing:
        // Mode-specific gradients
        if (widget.mode == NfcMode.p2pShare) {
          // Purple gradient for P2P mode
          return {
            'primary': const Color(0xFF9C27B0), // Material Purple 500
            'secondary': const Color(0xFF673AB7), // Material Deep Purple 500
          };
        } else {
          // Orange gradient for Tag Write mode (default)
          return {
            'primary': AppColors.primaryAction,
            'secondary': AppColors.secondaryAction,
          };
        }

      case NfcFabState.success:
        return {
          'primary': Colors.green.shade400,
          'secondary': Colors.green.shade600,
        };

      case NfcFabState.error:
        return {
          'primary': Colors.red.shade400,
          'secondary': Colors.red.shade600,
        };
    }
  }
}

/// FAB Status Text Widget
///
/// Displays dynamic status text below the NFC FAB based on current state and mode.
class NfcFabStatusText extends StatelessWidget {
  final NfcFabState state;
  final NfcMode mode;
  final bool nfcAvailable;

  const NfcFabStatusText({
    super.key,
    required this.state,
    required this.mode,
    required this.nfcAvailable,
  });

  @override
  Widget build(BuildContext context) {
    // Determine text and color based on state AND mode
    String text;
    Color textColor;

    if (!nfcAvailable) {
      text = 'NFC not available';
      textColor = AppColors.textSecondary;
    } else {
      // Mode-specific text
      final isTagWrite = mode == NfcMode.tagWrite;

      switch (state) {
        case NfcFabState.inactive:
          text = 'Tap to activate • Long press to switch modes';
          textColor = Colors.white.withOpacity(0.6); // Dull white
          break;

        case NfcFabState.active:
          text = isTagWrite ? 'Tap to Share' : 'Ready for Tap';
          textColor = AppColors.primaryAction; // Orange
          break;

        case NfcFabState.writing:
          // Writing state kept for compatibility but shows same as active
          text = isTagWrite ? 'Tap to Share' : 'Ready for Tap';
          textColor = AppColors.primaryAction; // Orange
          break;

        case NfcFabState.success:
          text = isTagWrite ? 'Written successfully!' : 'Shared successfully!';
          textColor = Colors.greenAccent;
          break;

        case NfcFabState.error:
          text = isTagWrite ? 'Write failed' : 'Share failed';
          textColor = Colors.redAccent;
          break;
      }
    }

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      style: AppTextStyles.h3.copyWith(
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      child: Text(
        text,
        key: const Key('home_tap_share_title'),
      ),
    );
  }
}

/// Share Options Button Widget
///
/// Glassmorphic button that opens the share modal with more sharing options.
class ShareOptionsButton extends StatelessWidget {
  final VoidCallback onTap;

  const ShareOptionsButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('home_share_options_material'),
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home_share_options_inkwell'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          key: const Key('home_share_options_clip'),
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            key: const Key('home_share_options_backdrop'),
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              key: const Key('home_share_options_container'),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                key: const Key('home_share_options_row'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.share,
                    key: Key('home_share_options_icon'),
                    size: 20,
                    color: AppColors.primaryAction,
                  ),
                  const SizedBox(
                      key: Key('home_share_options_text_spacing'),
                      width: 10),
                  Text(
                    'More sharing options',
                    key: const Key('home_share_options_text'),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primaryAction,
                      fontWeight: FontWeight.w600,
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
