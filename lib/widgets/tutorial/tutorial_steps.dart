import 'package:flutter/cupertino.dart';
import 'tutorial_keys.dart';

/// Position of the tutorial tooltip relative to the target widget
enum TooltipPosition {
  top,
  bottom,
  left,
  right,
  center,
}

/// A single step in the tutorial flow
class TutorialStep {
  /// Unique identifier for this step
  final String id;

  /// Key of the target widget to highlight (null for center overlay)
  final GlobalKey? targetKey;

  /// Title of the tutorial step
  final String title;

  /// Description text
  final String description;

  /// Icon to show in tooltip
  final IconData icon;

  /// Position of tooltip relative to target
  final TooltipPosition position;

  /// Whether this step requires user interaction
  final bool requiresInteraction;

  /// Custom action to perform (e.g., navigate to another screen)
  final Future<void> Function(BuildContext)? onStepAction;

  /// Whether to show "Skip Tutorial" button on this step
  final bool showSkipButton;

  const TutorialStep({
    required this.id,
    this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    this.position = TooltipPosition.bottom,
    this.requiresInteraction = false,
    this.onStepAction,
    this.showSkipButton = true,
  });
}

/// All tutorial steps in the app
class TutorialSteps {
  /// NFC FAB button introduction
  static final nfcFab = TutorialStep(
    id: 'nfc_fab',
    targetKey: TutorialKeys.homeNfcFabKey,
    title: 'Tap to Share',
    description: 'Activate NFC sharing with nearby devices',
    icon: CupertinoIcons.antenna_radiowaves_left_right,
    position: TooltipPosition.top,
  );

  /// Mode switching (long press)
  static final modeSwitch = TutorialStep(
    id: 'mode_switch',
    targetKey: TutorialKeys.homeModeIndicatorKey,
    title: 'Switch Modes',
    description: 'Long press to toggle between Tag Write and P2P Share',
    icon: CupertinoIcons.arrow_right_arrow_left,
    position: TooltipPosition.top,
  );

  /// More sharing options button
  static final shareOptions = TutorialStep(
    id: 'share_options',
    targetKey: TutorialKeys.homeShareOptionsKey,
    title: 'More Options',
    description: 'Access QR codes and shareable links',
    icon: CupertinoIcons.share,
    position: TooltipPosition.top,
  );

  /// Profile tab introduction
  static final profileTab = TutorialStep(
    id: 'profile_tab',
    targetKey: TutorialKeys.bottomNavProfileKey,
    title: 'Edit Your Card',
    description: 'Customize your digital business card',
    icon: CupertinoIcons.person_crop_circle,
    position: TooltipPosition.top,
  );

  /// Get all tutorial steps in order
  static List<TutorialStep> getAllSteps() {
    return [
      nfcFab,
      modeSwitch,
      shareOptions,
      profileTab,
    ];
  }

  /// Get a specific step by ID
  static TutorialStep? getStepById(String id) {
    try {
      return getAllSteps().firstWhere((step) => step.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get total number of steps
  static int get totalSteps => getAllSteps().length;
}
