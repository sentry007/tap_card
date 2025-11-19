/// Core application constants for Atlas Linq
///
/// This file contains all magic numbers, dimensions, durations, and configuration
/// values used throughout the application. Centralizing these values makes the
/// codebase more maintainable and easier to modify.
library;

import 'package:flutter/material.dart';
import '../../utils/responsive_helper.dart';

/// Spacing and Layout Constants
///
/// Uses an 8px grid system for consistent spacing throughout the app
class AppSpacing {
  AppSpacing._(); // Private constructor to prevent instantiation

  // Base unit (8px grid)
  static const double unit = 8.0;

  // Common spacing values (FIXED - for backward compatibility)
  static const double xs = unit * 0.5;   // 4px
  static const double sm = unit;         // 8px
  static const double md = unit * 2;     // 16px
  static const double lg = unit * 3;     // 24px
  static const double xl = unit * 4;     // 32px
  static const double xxl = unit * 5;    // 40px
  static const double xxxl = unit * 6;   // 48px

  // Specific UI spacing (FIXED - for backward compatibility)
  static const double cardPadding = lg;              // 24px
  static const double screenPadding = md;            // 16px
  static const double sectionSpacing = lg;           // 24px
  static const double itemSpacing = md;              // 16px
  static const double bottomNavHeight = 80.0;        // Bottom navigation height
  static const double appBarHeight = 64.0;           // App bar height

  // RESPONSIVE SPACING - Use these for new code or when refactoring

  /// Get responsive extra small spacing
  static double responsiveXs(BuildContext context) {
    return ResponsiveHelper.spacing(context, xs);
  }

  /// Get responsive small spacing
  static double responsiveSm(BuildContext context) {
    return ResponsiveHelper.spacing(context, sm);
  }

  /// Get responsive medium spacing
  static double responsiveMd(BuildContext context) {
    return ResponsiveHelper.spacing(context, md);
  }

  /// Get responsive large spacing
  static double responsiveLg(BuildContext context) {
    return ResponsiveHelper.spacing(context, lg);
  }

  /// Get responsive extra large spacing
  static double responsiveXl(BuildContext context) {
    return ResponsiveHelper.spacing(context, xl);
  }

  /// Get responsive double extra large spacing
  static double responsiveXxl(BuildContext context) {
    return ResponsiveHelper.spacing(context, xxl);
  }

  /// Get responsive triple extra large spacing
  static double responsiveXxxl(BuildContext context) {
    return ResponsiveHelper.spacing(context, xxxl);
  }

  /// Get responsive card padding
  static double responsiveCardPadding(BuildContext context) {
    return ResponsiveHelper.spacing(context, cardPadding);
  }

  /// Get responsive screen padding
  static double responsiveScreenPadding(BuildContext context) {
    return ResponsiveHelper.spacing(context, screenPadding);
  }

  /// Get responsive section spacing
  static double responsiveSectionSpacing(BuildContext context) {
    return ResponsiveHelper.spacing(context, sectionSpacing);
  }

  /// Get responsive item spacing
  static double responsiveItemSpacing(BuildContext context) {
    return ResponsiveHelper.spacing(context, itemSpacing);
  }

  /// Get responsive bottom navigation height (6-8% of screen height)
  static double responsiveBottomNavHeight(BuildContext context) {
    return ResponsiveHelper.responsiveHeight(
      context,
      percent: 0.07, // 7% of screen height
      min: 60.0,
      max: 80.0,
    );
  }

  /// Get responsive app bar height (5-7% of screen height)
  static double responsiveAppBarHeight(BuildContext context) {
    return ResponsiveHelper.responsiveHeight(
      context,
      percent: 0.06, // 6% of screen height
      min: 56.0,
      max: 72.0,
    );
  }
}

/// Border Radius Constants
class AppRadius {
  AppRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;

  // Specific UI elements
  static const double card = xl;           // 20px
  static const double button = md;         // 12px
  static const double dialog = xxl;        // 24px
  static const double textField = lg;      // 16px
}

/// Animation Duration Constants
///
/// Standard duration values for animations to maintain consistency
class AppDurations {
  AppDurations._();

  // Standard durations (in milliseconds)
  static const int fast = 200;
  static const int normal = 300;
  static const int medium = 500;
  static const int slow = 600;
  static const int verySlow = 1200;

  // Specific animations
  static const int fabAnimation = fast;              // 200ms
  static const int pulseAnimation = verySlow;        // 1200ms
  static const int rippleAnimation = 1500;           // 1500ms
  static const int pageTransition = fast;            // 200ms
  static const int formSlide = slow;                 // 600ms
  static const int cardScale = normal;               // 300ms
  static const int saveButton = fast;                // 200ms
  static const int snackbarDisplay = 3000;           // 3 seconds
  static const int snackbarError = 4000;             // 4 seconds
}

/// NFC Configuration Constants
///
/// Configuration values for NFC operations and payload management
class NFCConstants {
  NFCConstants._();

  // Payload size limits (in bytes)
  static const int ntag213MaxBytes = 144;           // NTAG213 capacity
  static const int ntag215MaxBytes = 504;           // NTAG215 capacity
  static const int ntag216MaxBytes = 888;           // NTAG216 capacity
  static const int targetPayloadSize = ntag213MaxBytes; // Target for optimization

  // Timeout values (in seconds)
  static const int sessionTimeoutSeconds = 30;      // NFC session timeout
  static const int discoveryTimeoutSeconds = 5;     // Device discovery timeout
  static const int writeTimeoutSeconds = 15;        // Write operation timeout (increased from 10s)

  // Timeout values (in milliseconds)
  static const int writeTimeoutMs = writeTimeoutSeconds * 1000;  // 15000ms
  static const int activityResumeDelayMs = 150;     // Delay for activity resume check
  static const int discoveryHoldPeriodMs = 7000;    // Discovery hold period after tag detected

  // Discovery service timeouts
  static const int discoveryRestartDelayMs = 500;   // Delay before restarting discovery

  // Cache management
  static const int cacheRefreshMinutes = 5;         // Refresh NFC payload cache every 5 minutes

  // Proximity requirements
  static const double maxDistanceCm = 4.0;          // Maximum NFC distance (4cm)

  // App identifier
  static const String appId = 'al';                 // Shortened app ID for compact payload
  static const String appIdFull = 'atlaslinq';      // Full app identifier
  static const String payloadVersion = '1';         // Payload format version

  // Tag capacity warnings (in bytes)
  static const int nearCapacityThreshold = 128;     // Warn when payload is near tag capacity
  static const int criticalCapacityThreshold = 140; // Critical warning threshold
}

/// Profile Configuration Constants
class ProfileConstants {
  ProfileConstants._();

  // Profile limits
  static const int maxProfiles = 3;                 // Maximum number of profiles
  static const int maxSocialLinks = 12;             // Maximum social media links

  // Validation
  static const int minNameLength = 1;
  static const int maxNameLength = 50;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 20;

  // Image constraints
  static const int profileImageMaxWidth = 512;
  static const int profileImageMaxHeight = 512;
  static const int backgroundImageMaxWidth = 1024;
  static const int backgroundImageMaxHeight = 1024;
  static const int profileImageQuality = 80;
  static const int backgroundImageQuality = 90;
}

/// UI Component Size Constants
class ComponentSizes {
  ComponentSizes._();

  // Icon sizes (FIXED - for backward compatibility)
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double iconXxl = 56.0;

  // Avatar sizes (FIXED - for backward compatibility)
  static const double avatarSm = 32.0;
  static const double avatarMd = 45.0;
  static const double avatarLg = 60.0;

  // Button heights (FIXED - for backward compatibility)
  static const double buttonSm = 40.0;
  static const double buttonMd = 48.0;
  static const double buttonLg = 56.0;

  // Card sizes (FIXED - for backward compatibility)
  static const double contactCardWidth = 72.0;
  static const double contactCardHeight = 88.0;
  static const double profileCardHeight = 180.0;
  static const double profileCardWidth = 300.0;
  static const double livePreviewHeight = 200.0;

  // FAB sizes (FIXED - for backward compatibility)
  static const double fabContainerSize = 120.0;
  static const double fabMainSize = 96.0;
  static const double fabIconSize = 56.0;

  // RESPONSIVE COMPONENT SIZES - Use these for new code or when refactoring

  /// Get responsive icon size (extra small)
  static double responsiveIconXs(BuildContext context) {
    return ResponsiveHelper.iconSize(context, iconXs);
  }

  /// Get responsive icon size (small)
  static double responsiveIconSm(BuildContext context) {
    return ResponsiveHelper.iconSize(context, iconSm);
  }

  /// Get responsive icon size (medium)
  static double responsiveIconMd(BuildContext context) {
    return ResponsiveHelper.iconSize(context, iconMd);
  }

  /// Get responsive icon size (large)
  static double responsiveIconLg(BuildContext context) {
    return ResponsiveHelper.iconSize(context, iconLg);
  }

  /// Get responsive icon size (extra large)
  static double responsiveIconXl(BuildContext context) {
    return ResponsiveHelper.iconSize(context, iconXl);
  }

  /// Get responsive icon size (double extra large)
  static double responsiveIconXxl(BuildContext context) {
    return ResponsiveHelper.iconSize(context, iconXxl);
  }

  /// Get responsive avatar size (small)
  static double responsiveAvatarSm(BuildContext context) {
    return ResponsiveHelper.iconSize(context, avatarSm);
  }

  /// Get responsive avatar size (medium)
  static double responsiveAvatarMd(BuildContext context) {
    return ResponsiveHelper.iconSize(context, avatarMd);
  }

  /// Get responsive avatar size (large)
  static double responsiveAvatarLg(BuildContext context) {
    return ResponsiveHelper.iconSize(context, avatarLg);
  }

  /// Get responsive button height (small)
  static double responsiveButtonSm(BuildContext context) {
    return ResponsiveHelper.responsiveHeight(
      context,
      percent: 0.05, // 5% of screen height
      min: 36.0,
      max: 44.0,
    );
  }

  /// Get responsive button height (medium)
  static double responsiveButtonMd(BuildContext context) {
    return ResponsiveHelper.responsiveHeight(
      context,
      percent: 0.06, // 6% of screen height
      min: 44.0,
      max: 52.0,
    );
  }

  /// Get responsive button height (large)
  static double responsiveButtonLg(BuildContext context) {
    return ResponsiveHelper.responsiveHeight(
      context,
      percent: 0.07, // 7% of screen height
      min: 52.0,
      max: 60.0,
    );
  }

  /// Get responsive contact card size
  static Size responsiveContactCard(BuildContext context) {
    return ResponsiveHelper.responsiveSize(
      context,
      baseWidth: contactCardWidth,
      baseHeight: contactCardHeight,
      widthPercent: 0.19, // 19% of screen width
      minWidth: 64.0,
      maxWidth: 80.0,
    );
  }

  /// Get responsive profile card height
  static double responsiveProfileCardHeight(BuildContext context) {
    return ResponsiveHelper.responsiveHeight(
      context,
      percent: 0.22, // 22% of screen height
      min: 160.0,
      max: 220.0,
    );
  }

  /// Get responsive profile card width
  static double responsiveProfileCardWidth(BuildContext context) {
    return ResponsiveHelper.responsiveWidth(
      context,
      percent: 0.8, // 80% of screen width
      min: 280.0,
      max: 360.0,
    );
  }

  /// Get responsive live preview height
  static double responsiveLivePreviewHeight(BuildContext context) {
    return ResponsiveHelper.responsiveHeight(
      context,
      percent: 0.25, // 25% of screen height
      min: 180.0,
      max: 240.0,
    );
  }

  /// Get responsive FAB container size (maintains aspect ratio)
  static Size responsiveFabContainer(BuildContext context) {
    return ResponsiveHelper.responsiveSize(
      context,
      baseWidth: 240.0,
      baseHeight: 120.0,
      widthPercent: 0.6, // 60% of screen width
      minWidth: 200.0,
      maxWidth: 280.0,
    );
  }

  /// Get responsive FAB main size (maintains aspect ratio)
  static Size responsiveFabMain(BuildContext context) {
    return ResponsiveHelper.responsiveSize(
      context,
      baseWidth: 192.0,
      baseHeight: 96.0,
      widthPercent: 0.48, // 48% of screen width
      minWidth: 160.0,
      maxWidth: 224.0,
    );
  }

  /// Get responsive FAB icon size
  static double responsiveFabIcon(BuildContext context) {
    return ResponsiveHelper.iconSize(context, fabIconSize);
  }
}

/// Glassmorphism Effect Constants
class GlassConstants {
  GlassConstants._();

  // Blur levels
  static const double blurMin = 0.0;
  static const double blurMax = 18.0;
  static const double blurDefault = 10.0;
  static const int blurDivisions = 36;              // Slider divisions

  // Opacity levels
  static const double backgroundOpacityLight = 0.1;
  static const double backgroundOpacityMedium = 0.2;
  static const double borderOpacityLight = 0.1;
  static const double borderOpacityMedium = 0.2;
  static const double borderOpacityStrong = 0.3;
}

/// Color Picker Constants
class ColorPickerConstants {
  ColorPickerConstants._();

  static const int recentColorsMax = 3;             // Max recent color combinations to save
  static const double colorSwatchSize = 44.0;       // Color swatch button size
  static const double colorSwatchSpacing = 12.0;    // Spacing between swatches
  static const double pickerWidth = 250.0;          // Color picker width
  static const double pickerAreaHeight = 0.7;       // Picker area height percentage
}

/// Animation Scale Constants
class AnimationScales {
  AnimationScales._();

  // Scale values
  static const double scaleMin = 0.8;
  static const double scaleNormal = 1.0;
  static const double scalePressed = 0.92;
  static const double scaleExpanded = 0.95;
  static const double scalePulse = 1.08;
  static const double scaleRipple = 2.2;

  // Opacity values
  static const double opacityMin = 0.0;
  static const double opacityFaded = 0.25;
  static const double opacityMedium = 0.5;
  static const double opacityStrong = 0.7;
  static const double opacityFull = 1.0;
}

/// History and Activity Constants
class HistoryConstants {
  HistoryConstants._();

  static const int maxHistoryItems = 100;           // Maximum history items to store
  static const int recentHistoryDisplay = 4;        // Number of recent items to display
  static const int recentContactsDisplay = 5;       // Number of recent contacts to display
  static const double historyListHeight = 200.0;    // History list container height
}

/// Local Storage Keys
///
/// Keys used for SharedPreferences and local storage
class StorageKeys {
  StorageKeys._();

  // App state
  static const String isFirstLaunch = 'is_first_launch';
  static const String hasCompletedOnboarding = 'has_completed_onboarding';
  static const String isAuthenticated = 'is_authenticated';
  static const String currentUserId = 'current_user_id';
  static const String hasSharedOrReceived = 'has_shared_or_received';

  // Profile data
  static const String userProfiles = 'user_profiles';
  static const String profileSettings = 'profile_settings';
  static const String activeProfileId = 'active_profile_id';
}

/// Firebase Configuration Constants
///
/// TODO: Firebase integration - Configure these values when setting up Firebase
class FirebaseConstants {
  FirebaseConstants._();

  // Collection names
  static const String usersCollection = 'users';
  static const String profilesCollection = 'profiles';
  static const String contactsCollection = 'contacts';
  static const String historyCollection = 'history';

  // Sync intervals
  static const int syncIntervalMinutes = 5;         // TODO: Firebase - Profile sync interval
  static const int offlineRetryMinutes = 15;        // TODO: Firebase - Retry interval when offline

  // Field names (shortened for compact storage)
  static const String fieldName = 'n';
  static const String fieldPhone = 'p';
  static const String fieldEmail = 'e';
  static const String fieldCompany = 'c';
  static const String fieldTitle = 't';
}

/// Network and API Constants
///
/// TODO: Configure when backend API is implemented
class NetworkConstants {
  NetworkConstants._();

  static const int connectionTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;
  static const int maxRetries = 3;

  // TODO: API - Set base URL when backend is deployed
  // static const String baseUrl = 'https://api.tapcard.app';
}
