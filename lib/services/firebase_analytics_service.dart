/// Firebase Analytics Service
///
/// Centralized analytics tracking for user actions, screen views, and events
/// Uses Firebase Analytics for automatic insights and dashboards
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as developer;

class FirebaseAnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Track app screen view
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      developer.log(
        '📊 Screen view tracked: $screenName',
        name: 'Analytics.ScreenView',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to track screen view: $e',
        name: 'Analytics.ScreenView',
        error: e,
      );
    }
  }

  /// Track contact saved to device
  static Future<void> logContactSaved({
    required String profileId,
    required String method, // 'nfc', 'qr', 'web'
    bool hasMetadata = false,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'contact_saved',
        parameters: {
          'profile_id': profileId,
          'method': method,
          'has_metadata': hasMetadata,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      developer.log(
        '📊 Contact saved tracked: $profileId (method: $method)',
        name: 'Analytics.ContactSaved',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to track contact saved: $e',
        name: 'Analytics.ContactSaved',
        error: e,
      );
    }
  }

  /// Track contact viewed in app
  static Future<void> logContactViewed({
    required String profileId,
    required String source, // 'history', 'search', 'notification'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'contact_viewed',
        parameters: {
          'profile_id': profileId,
          'source': source,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      developer.log(
        '📊 Contact viewed tracked: $profileId (source: $source)',
        name: 'Analytics.ContactViewed',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to track contact viewed: $e',
        name: 'Analytics.ContactViewed',
        error: e,
      );
    }
  }

  /// Track profile view (web profile page view)
  ///
  /// Increments Firestore viewCount via Cloud Function and logs Analytics event
  /// Called when:
  /// - User taps NFC card and views shared profile
  /// - User scans QR code
  /// - User clicks received contact link
  /// - User views contact from history
  ///
  /// Source options:
  /// - 'app_nfc': NFC tap
  /// - 'app_qr': QR code scan
  /// - 'app_link': Opened from link
  /// - 'app_history': Viewed from history
  static Future<void> logProfileView({
    required String profileId,
    required String profileType,
    String source = 'app_nfc',
  }) async {
    try {
      // 1. Log Analytics event (for dashboards/insights)
      await _analytics.logEvent(
        name: 'profile_view',
        parameters: {
          'profile_id': profileId,
          'profile_type': profileType,
          'view_source': source,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      developer.log(
        '📊 Profile view tracked in Analytics: $profileId',
        name: 'Analytics.ProfileView',
      );

      // 2. Increment Firestore view count via Cloud Function
      try {
        final incrementView = _functions.httpsCallable('incrementProfileView');
        final result = await incrementView.call({
          'profileId': profileId,
          'source': source,
        });

        final data = result.data as Map<String, dynamic>;
        final viewCount = data['viewCount'] as int? ?? 0;
        final rateLimited = data['rateLimited'] as bool? ?? false;

        if (rateLimited) {
          developer.log(
            '⏱️ Profile view rate limited: $profileId (count: $viewCount)',
            name: 'Analytics.ProfileView',
          );
        } else {
          developer.log(
            '✅ Profile view count incremented: $profileId → $viewCount',
            name: 'Analytics.ProfileView',
          );
        }
      } catch (functionError) {
        // Don't fail the entire operation if Cloud Function fails
        developer.log(
          '⚠️ Failed to increment view count (non-critical): $functionError',
          name: 'Analytics.ProfileView',
          error: functionError,
        );
      }
    } catch (e) {
      developer.log(
        '❌ Failed to track profile view: $e',
        name: 'Analytics.ProfileView',
        error: e,
      );
    }
  }

  /// Track NFC tap event
  static Future<void> logNfcTap({
    required String profileId,
    String? tagType,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'nfc_tap',
        parameters: {
          'profile_id': profileId,
          if (tagType != null) 'tag_type': tagType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      developer.log(
        '📊 NFC tap tracked: $profileId${tagType != null ? " (type: $tagType)" : ""}',
        name: 'Analytics.NfcTap',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to track NFC tap: $e',
        name: 'Analytics.NfcTap',
        error: e,
      );
    }
  }

  /// Track NFC write event
  static Future<void> logNfcWrite({
    required String tagId,
    required String profileId,
    String? tagType,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'nfc_write',
        parameters: {
          'tag_id': tagId,
          'profile_id': profileId,
          if (tagType != null) 'tag_type': tagType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      developer.log(
        '📊 NFC write tracked: tag=$tagId, profile=$profileId',
        name: 'Analytics.NfcWrite',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to track NFC write: $e',
        name: 'Analytics.NfcWrite',
        error: e,
      );
    }
  }

  /// Track QR code scan
  static Future<void> logQrScan({
    required String profileId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'qr_scan',
        parameters: {
          'profile_id': profileId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      developer.log(
        '📊 QR scan tracked: $profileId',
        name: 'Analytics.QrScan',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to track QR scan: $e',
        name: 'Analytics.QrScan',
        error: e,
      );
    }
  }

  /// Track contact deleted
  static Future<void> logContactDeleted({
    required String profileId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'contact_deleted',
        parameters: {
          'profile_id': profileId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      developer.log(
        '📊 Contact deleted tracked: $profileId',
        name: 'Analytics.ContactDeleted',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to track contact deleted: $e',
        name: 'Analytics.ContactDeleted',
        error: e,
      );
    }
  }

  /// Track profile shared
  static Future<void> logProfileShared({
    required String profileId,
    required String method, // 'nfc', 'qr', 'link'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'share',
        parameters: {
          'content_type': 'profile',
          'item_id': profileId,
          'method': method,
          'profile_id': profileId,
        },
      );
      developer.log(
        '📊 Profile shared tracked: $profileId (method: $method)',
        name: 'Analytics.ProfileShared',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to track profile shared: $e',
        name: 'Analytics.ProfileShared',
        error: e,
      );
    }
  }

  /// Track custom event
  static Future<void> logCustomEvent({
    required String eventName,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters,
      );
      developer.log(
        '📊 Custom event tracked: $eventName',
        name: 'Analytics.CustomEvent',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to track custom event: $e',
        name: 'Analytics.CustomEvent',
        error: e,
      );
    }
  }

  /// Set user properties for segmentation
  static Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      developer.log(
        '📊 User property set: $name=$value',
        name: 'Analytics.UserProperty',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to set user property: $e',
        name: 'Analytics.UserProperty',
        error: e,
      );
    }
  }

  /// Set user ID for tracking across sessions
  static Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      developer.log(
        '📊 User ID set: $userId',
        name: 'Analytics.UserId',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to set user ID: $e',
        name: 'Analytics.UserId',
        error: e,
      );
    }
  }
}
