/// NFC Settings Service
///
/// Manages user preferences for NFC functionality including:
/// - Default NFC mode (Tag Write vs P2P Share)
/// - Location tracking preferences
///
/// Uses SharedPreferences for persistence across app restarts.
library;

import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

import 'nfc_service.dart'; // For NfcMode enum

/// Singleton service for managing NFC-related settings
class NfcSettingsService {
  static final NfcSettingsService _instance = NfcSettingsService._internal();
  factory NfcSettingsService() => _instance;
  NfcSettingsService._internal();

  // SharedPreferences keys
  static const String _defaultModeKey = 'nfc_default_mode';
  static const String _locationTrackingKey = 'nfc_location_tracking';

  static bool _isInitialized = false;
  static SharedPreferences? _prefs;

  /// Initialize the service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      developer.log('✅ NfcSettingsService initialized', name: 'NFC.Settings');
    } catch (e) {
      developer.log(
        '❌ Failed to initialize NfcSettingsService: $e',
        name: 'NFC.Settings',
        error: e
      );
    }
  }

  /// Get the default NFC mode
  /// Returns [NfcMode.tagWrite] if not set or on error
  static Future<NfcMode> getDefaultMode() async {
    await _ensureInitialized();

    try {
      final modeString = _prefs?.getString(_defaultModeKey);
      if (modeString == null) {
        return NfcMode.tagWrite; // Default to Tag Write
      }

      // Parse enum from string
      if (modeString == 'tagWrite') {
        return NfcMode.tagWrite;
      } else if (modeString == 'p2pShare') {
        return NfcMode.p2pShare;
      } else {
        developer.log(
          '⚠️ Unknown NFC mode in preferences: $modeString, defaulting to tagWrite',
          name: 'NFC.Settings'
        );
        return NfcMode.tagWrite;
      }
    } catch (e) {
      developer.log(
        '❌ Error getting default NFC mode: $e',
        name: 'NFC.Settings',
        error: e
      );
      return NfcMode.tagWrite;
    }
  }

  /// Set the default NFC mode
  static Future<void> setDefaultMode(NfcMode mode) async {
    await _ensureInitialized();

    try {
      final modeString = mode == NfcMode.tagWrite ? 'tagWrite' : 'p2pShare';
      await _prefs?.setString(_defaultModeKey, modeString);
      developer.log(
        '✅ Default NFC mode set to: ${mode.name}',
        name: 'NFC.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting default NFC mode: $e',
        name: 'NFC.Settings',
        error: e
      );
    }
  }

  /// Check if location tracking is enabled
  /// Returns false by default (opt-in for privacy)
  static Future<bool> getLocationTrackingEnabled() async {
    await _ensureInitialized();

    try {
      return _prefs?.getBool(_locationTrackingKey) ?? false;
    } catch (e) {
      developer.log(
        '❌ Error getting location tracking setting: $e',
        name: 'NFC.Settings',
        error: e
      );
      return false;
    }
  }

  /// Set location tracking preference
  static Future<void> setLocationTrackingEnabled(bool enabled) async {
    await _ensureInitialized();

    try {
      await _prefs?.setBool(_locationTrackingKey, enabled);
      developer.log(
        '✅ Location tracking ${enabled ? 'enabled' : 'disabled'}',
        name: 'NFC.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting location tracking: $e',
        name: 'NFC.Settings',
        error: e
      );
    }
  }

  /// Ensure service is initialized
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Reset all settings to defaults (for testing/debugging)
  static Future<void> resetToDefaults() async {
    await _ensureInitialized();

    try {
      await _prefs?.remove(_defaultModeKey);
      await _prefs?.remove(_locationTrackingKey);
      developer.log('🔄 NFC settings reset to defaults', name: 'NFC.Settings');
    } catch (e) {
      developer.log(
        '❌ Error resetting NFC settings: $e',
        name: 'NFC.Settings',
        error: e
      );
    }
  }
}
