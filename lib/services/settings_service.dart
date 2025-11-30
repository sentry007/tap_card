/// Settings Service
///
/// Manages user preferences for app settings including:
/// - Privacy & Security (analytics, crash reporting)
/// - NFC (enabled, auto share)
/// - History (retention days)
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

  // NFC
  static const String _nfcEnabledKey = 'settings_nfc_enabled';
  static const String _autoShareKey = 'settings_auto_share';

  // History
  static const String _historyRetentionKey = 'settings_history_retention';

  // Developer Settings
  static const String _devModeKey = 'settings_dev_mode';

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

  // ========== History Settings ==========

  /// Get history retention days (default: 365 = keep forever)
  static Future<int> getHistoryRetentionDays() async {
    await _ensureInitialized();
    try {
      return _prefs?.getInt(_historyRetentionKey) ?? 365;
    } catch (e) {
      developer.log('❌ Error getting history retention: $e', name: 'Settings.Service', error: e);
      return 365;
    }
  }

  /// Set history retention days
  static Future<void> setHistoryRetentionDays(int days) async {
    await _ensureInitialized();
    try {
      await _prefs?.setInt(_historyRetentionKey, days);
      developer.log('✅ History retention set to $days days', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting history retention: $e', name: 'Settings.Service', error: e);
    }
  }

  // ========== Developer Settings ==========

  /// Get dev mode enabled setting (default: false)
  static Future<bool> getDevModeEnabled() async {
    await _ensureInitialized();
    try {
      return _prefs?.getBool(_devModeKey) ?? false;
    } catch (e) {
      developer.log('❌ Error getting dev mode setting: $e', name: 'Settings.Service', error: e);
      return false;
    }
  }

  /// Set dev mode enabled
  static Future<void> setDevModeEnabled(bool enabled) async {
    await _ensureInitialized();
    try {
      await _prefs?.setBool(_devModeKey, enabled);
      developer.log('✅ Dev mode ${enabled ? 'enabled' : 'disabled'}', name: 'Settings.Service');
    } catch (e) {
      developer.log('❌ Error setting dev mode: $e', name: 'Settings.Service', error: e);
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

      // NFC
      'nfcEnabled': await getNfcEnabled(),
      'autoShare': await getAutoShareEnabled(),

      // History
      'historyRetentionDays': await getHistoryRetentionDays(),

      // Developer
      'devModeEnabled': await getDevModeEnabled(),
    };
  }

  /// Reset all settings to defaults (for testing/debugging)
  static Future<void> resetToDefaults() async {
    await _ensureInitialized();

    try {
      await _prefs?.remove(_analyticsEnabledKey);
      await _prefs?.remove(_crashReportingKey);
      await _prefs?.remove(_nfcEnabledKey);
      await _prefs?.remove(_autoShareKey);
      await _prefs?.remove(_historyRetentionKey);
      await _prefs?.remove(_devModeKey);

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
