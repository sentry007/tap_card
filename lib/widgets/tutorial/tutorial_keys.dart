import 'package:flutter/material.dart';

/// Central location for all tutorial-related GlobalKeys
/// These keys are used to highlight specific widgets during the tutorial
class TutorialKeys {
  // Home Screen Keys
  static final GlobalKey homeNfcFabKey = GlobalKey(debugLabel: 'tutorial_home_nfc_fab');
  static final GlobalKey homeShareOptionsKey = GlobalKey(debugLabel: 'tutorial_home_share_options');
  static final GlobalKey homeModeIndicatorKey = GlobalKey(debugLabel: 'tutorial_home_mode_indicator');

  // Profile Screen Keys
  static final GlobalKey profilePreviewCardKey = GlobalKey(debugLabel: 'tutorial_profile_preview_card');

  // Bottom Navigation Keys
  static final GlobalKey bottomNavProfileKey = GlobalKey(debugLabel: 'tutorial_bottom_nav_profile');
  static final GlobalKey bottomNavHistoryKey = GlobalKey(debugLabel: 'tutorial_bottom_nav_history');
}
