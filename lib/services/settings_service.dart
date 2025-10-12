/// Settings Service
///
/// Manages user preferences for app settings including:
/// - Privacy & Security (analytics, crash reporting, share expiry)
/// - Notifications (push, share, receive, sound, vibration)
/// - NFC (enabled, auto share)
///
/// Uses SharedPreferences for persistence across app restarts.
library;

import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for managing app settings
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // SharedPreferences keys
  // Privacy & Security
  static const String _analyticsEnabledKey = 'settings_analytics_enabled';
  static const String _crashReportingKey = 'settings_crash_reporting';
  static const String _shareExpiryKey = 'settings_share_expiry';

  // Notifications
  static const String _pushNotificationsKey = 'settings_push_notifications';
  static const String _shareNotificationsKey = 'settings_share_notifications';
  static const String _receiveNotificationsKey = 'settings_receive_notifications';
  static const String _soundEnabledKey = 'settings_sound_enabled';
  static const String _vibrationEnabledKey = 'settings_vibration_enabled';

  // NFC
  static const String _nfcEnabledKey = 'settings_nfc_enabled';
  static const String _autoShareKey = 'settings_auto_share';

  static bool _isInitialized = false;
  static SharedPreferences? _prefs;

  /// Initialize the service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      developer.log('✅ SettingsService initialized', name: 'Settings.Service');
    } catch (e) {
      developer.log(
        '❌ Failed to initialize SettingsService: $e',
        name: 'Settings.Service',
        error: e
      );
    }
  }

  // ========== Privacy & Security Settings ==========

  /// Get analytics enabled setting (default: true)
  static Future<bool> getAnalyticsEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_analyticsEnabledKey) ?? true;
    } catch (e) {
      developer.log('❌ Error getting analytics setting: $e', name: 'Settings.Service', error: e);
      return true;
    }
  }

  /// Set analytics enabled
  static Future<void> setAnalyticsEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_analyticsEnabledKey, enabled);
      developer.log('✅ Analytics ${enabled ? 'enabled' : 'disabled'}', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting analytics: $e', name: 'Settings.Service', error: e);
    }
  }

  /// Get crash reporting enabled setting (default: true)
  static Future<bool> getCrashReportingEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_crashReportingKey) ?? true;
    } catch (e) {
      developer.log('❌ Error getting crash reporting setting: $e', name: 'Settings.Service', error: e);
      return true;
    }
  }

  /// Set crash reporting enabled
  static Future<void> setCrashReportingEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_crashReportingKey, enabled);
      developer.log('✅ Crash reporting ${enabled ? 'enabled' : 'disabled'}', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting crash reporting: $e', name: 'Settings.Service', error: e);
    }
  }

  /// Get share expiry days (default: 30)
  static Future<int> getShareExpiryDays() async {
    await _ensureInitialized();
    try {
      return _prefs?.getInt(_shareExpiryKey) ?? 30;
    } catch (e) {
      developer.log('❌ Error getting share expiry: $e', name: 'Settings.Service', error: e);
      return 30;
    }
  }

  /// Set share expiry days
  static Future<void> setShareExpiryDays(int days) async {
    await _ensureInitialized();
    try {
      await _prefs?.setInt(_shareExpiryKey, days);
      developer.log('✅ Share expiry set to $days days', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting share expiry: $e', name: 'Settings.Service', error: e);
    }
  }

  // ========== Notification Settings ==========

  /// Get push notifications enabled (default: true)
  static Future<bool> getPushNotificationsEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_pushNotificationsKey) ?? true;
    } catch (e) {
      developer.log('❌ Error getting push notifications: $e', name: 'Settings.Service', error: e);
      return true;
    }
  }

  /// Set push notifications enabled
  static Future<void> setPushNotificationsEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_pushNotificationsKey, enabled);
      developer.log('✅ Push notifications ${enabled ? 'enabled' : 'disabled'}', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting push notifications: $e', name: 'Settings.Service', error: e);
    }
  }

  /// Get share notifications enabled (default: true)
  static Future<bool> getShareNotificationsEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_shareNotificationsKey) ?? true;
    } catch (e) {
      developer.log('❌ Error getting share notifications: $e', name: 'Settings.Service', error: e);
      return true;
    }
  }

  /// Set share notifications enabled
  static Future<void> setShareNotificationsEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_shareNotificationsKey, enabled);
      developer.log('✅ Share notifications ${enabled ? 'enabled' : 'disabled'}', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting share notifications: $e', name: 'Settings.Service', error: e);
    }
  }

  /// Get receive notifications enabled (default: true)
  static Future<bool> getReceiveNotificationsEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_receiveNotificationsKey) ?? true;
    } catch (e) {
      developer.log('❌ Error getting receive notifications: $e', name: 'Settings.Service', error: e);
      return true;
    }
  }

  /// Set receive notifications enabled
  static Future<void> setReceiveNotificationsEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_receiveNotificationsKey, enabled);
      developer.log('✅ Receive notifications ${enabled ? 'enabled' : 'disabled'}', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting receive notifications: $e', name: 'Settings.Service', error: e);
    }
  }

  /// Get sound enabled (default: true)
  static Future<bool> getSoundEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_soundEnabledKey) ?? true;
    } catch (e) {
      developer.log('❌ Error getting sound setting: $e', name: 'Settings.Service', error: e);
      return true;
    }
  }

  /// Set sound enabled
  static Future<void> setSoundEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_soundEnabledKey, enabled);
      developer.log('✅ Sound ${enabled ? 'enabled' : 'disabled'}', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting sound: $e', name: 'Settings.Service', error: e);
    }
  }

  /// Get vibration enabled (default: true)
  static Future<bool> getVibrationEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_vibrationEnabledKey) ?? true;
    } catch (e) {
      developer.log('❌ Error getting vibration setting: $e', name: 'Settings.Service', error: e);
      return true;
    }
  }

  /// Set vibration enabled
  static Future<void> setVibrationEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_vibrationEnabledKey, enabled);
      developer.log('✅ Vibration ${enabled ? 'enabled' : 'disabled'}', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting vibration: $e', name: 'Settings.Service', error: e);
    }
  }

  // ========== NFC Settings ==========

  /// Get NFC enabled (app-level, default: true)
  static Future<bool> getNfcEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_nfcEnabledKey) ?? true;
    } catch (e) {
      developer.log('❌ Error getting NFC setting: $e', name: 'Settings.Service', error: e);
      return true;
    }
  }

  /// Set NFC enabled (app-level only)
  static Future<void> setNfcEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_nfcEnabledKey, enabled);
      developer.log('✅ NFC ${enabled ? 'enabled' : 'disabled'} (app-level)', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting NFC: $e', name: 'Settings.Service', error: e);
    }
  }

  /// Get auto share enabled (default: false)
  static Future<bool> getAutoShareEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_autoShareKey) ?? false;
    } catch (e) {
      developer.log('❌ Error getting auto share setting: $e', name: 'Settings.Service', error: e);
      return false;
    }
  }

  /// Set auto share enabled
  static Future<void> setAutoShareEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_autoShareKey, enabled);
      developer.log('✅ Auto share ${enabled ? 'enabled' : 'disabled'}', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting auto share: $e', name: 'Settings.Service', error: e);
    }
  }

  // ========== Utility Methods ==========

  /// Load all settings at once (for initialization)
  static Future<Map<String, dynamic>> loadAllSettings() async {
    await _ensureInitialized();

    return {
      // Privacy & Security
      'analyticsEnabled': await getAnalyticsEnabled(),
      'crashReporting': await getCrashReportingEnabled(),
      'shareExpiry': await getShareExpiryDays(),

      // Notifications
      'pushNotifications': await getPushNotificationsEnabled(),
      'shareNotifications': await getShareNotificationsEnabled(),
      'receiveNotifications': await getReceiveNotificationsEnabled(),
      'soundEnabled': await getSoundEnabled(),
      'vibrationEnabled': await getVibrationEnabled(),

      // NFC
      'nfcEnabled': await getNfcEnabled(),
      'autoShare': await getAutoShareEnabled(),
    };
  }

  /// Reset all settings to defaults (for testing/debugging)
  static Future<void> resetToDefaults() async {
    await _ensureInitialized();

    try {
      await _prefs?.remove(_analyticsEnabledKey);
      await _prefs?.remove(_crashReportingKey);
      await _prefs?.remove(_shareExpiryKey);
      await _prefs?.remove(_pushNotificationsKey);
      await _prefs?.remove(_shareNotificationsKey);
      await _prefs?.remove(_receiveNotificationsKey);
      await _prefs?.remove(_soundEnabledKey);
      await _prefs?.remove(_vibrationEnabledKey);
      await _prefs?.remove(_nfcEnabledKey);
      await _prefs?.remove(_autoShareKey);

      developer.log('🔄 Settings reset to defaults', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error resetting settings: $e', name: 'Settings.Service', error: e);
    }
  }

  /// Ensure service is initialized
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
