/// QR Settings Service
///
/// Manages user preferences for QR code generation including:
/// - QR code size (small/medium/large)
/// - Error correction level (L/M/Q/H)
/// - Include logo overlay
/// - QR code color scheme
///
/// Uses SharedPreferences for persistence across app restarts.
library;

import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr/qr.dart' show QrErrorCorrectLevel;

/// QR Code size presets
enum QrSize {
  small(120, 'Small'),
  medium(180, 'Medium'),
  large(240, 'Large');

  const QrSize(this.pixels, this.label);
  final int pixels;
  final String label;
}

/// QR Code logo type options
enum QrLogoType {
  atlasLogo(0, 'Atlas Linq Logo'),
  initials(1, 'My Initials'),
  profileImage(2, 'My Profile Picture');

  const QrLogoType(this.value, this.label);
  final int value;
  final String label;

  static QrLogoType fromValue(int value) {
    return QrLogoType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => QrLogoType.atlasLogo,
    );
  }
}

/// Singleton service for managing QR-related settings
class QrSettingsService {
  static final QrSettingsService _instance = QrSettingsService._internal();
  factory QrSettingsService() => _instance;
  QrSettingsService._internal();

  // SharedPreferences keys
  static const String _qrSizeKey = 'qr_size';
  static const String _qrErrorCorrectionKey = 'qr_error_correction';
  static const String _qrIncludeLogoKey = 'qr_include_logo';
  static const String _qrColorModeKey = 'qr_color_mode';
  static const String _qrBorderColorKey = 'qr_border_color';
  static const String _qrInitialsKey = 'qr_initials';
  static const String _qrShowInitialsKey = 'qr_show_initials';
  static const String _qrLogoTypeKey = 'qr_logo_type';
  static const String _qrPayloadTypeKey = 'qr_payload_type';

  static bool _isInitialized = false;
  static SharedPreferences? _prefs;

  /// Initialize the service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      developer.log('✅ QrSettingsService initialized', name: 'QR.Settings');
    } catch (e) {
      developer.log(
        '❌ Failed to initialize QrSettingsService: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }

  /// Get QR code size preference
  /// Returns [QrSize.medium] if not set or on error
  static Future<QrSize> getQrSize() async {
    await _ensureInitialized();

    try {
      final sizeString = _prefs?.getString(_qrSizeKey);
      if (sizeString == null) {
        return QrSize.medium; // Default to medium
      }

      switch (sizeString) {
        case 'small':
          return QrSize.small;
        case 'medium':
          return QrSize.medium;
        case 'large':
          return QrSize.large;
        default:
          developer.log(
            '⚠️ Unknown QR size in preferences: $sizeString, defaulting to medium',
            name: 'QR.Settings'
          );
          return QrSize.medium;
      }
    } catch (e) {
      developer.log(
        '❌ Error getting QR size: $e',
        name: 'QR.Settings',
        error: e
      );
      return QrSize.medium;
    }
  }

  /// Set QR code size preference
  static Future<void> setQrSize(QrSize size) async {
    await _ensureInitialized();

    try {
      final sizeString = size.name;
      await _prefs?.setString(_qrSizeKey, sizeString);
      developer.log(
        '✅ QR size set to: ${size.label}',
        name: 'QR.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting QR size: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }

  /// Get QR error correction level
  /// Returns [QrErrorCorrectLevel.M] if not set or on error
  static Future<int> getErrorCorrectionLevel() async {
    await _ensureInitialized();

    try {
      final level = _prefs?.getInt(_qrErrorCorrectionKey);
      if (level == null) {
        return QrErrorCorrectLevel.M; // Default to medium
      }
      return level;
    } catch (e) {
      developer.log(
        '❌ Error getting error correction level: $e',
        name: 'QR.Settings',
        error: e
      );
      return QrErrorCorrectLevel.M;
    }
  }

  /// Set QR error correction level
  static Future<void> setErrorCorrectionLevel(int level) async {
    await _ensureInitialized();

    try {
      await _prefs?.setInt(_qrErrorCorrectionKey, level);
      final levelName = _getErrorCorrectionLevelName(level);
      developer.log(
        '✅ Error correction level set to: $levelName',
        name: 'QR.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting error correction level: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }

  /// Get whether to include logo overlay
  /// Returns false by default (cleaner QR code)
  static Future<bool> getIncludeLogo() async {
    await _ensureInitialized();

    try {
      return _prefs?.getBool(_qrIncludeLogoKey) ?? false;
    } catch (e) {
      developer.log(
        '❌ Error getting include logo setting: $e',
        name: 'QR.Settings',
        error: e
      );
      return false;
    }
  }

  /// Set whether to include logo overlay
  static Future<void> setIncludeLogo(bool include) async {
    await _ensureInitialized();

    try {
      await _prefs?.setBool(_qrIncludeLogoKey, include);
      developer.log(
        '✅ Include logo ${include ? 'enabled' : 'disabled'}',
        name: 'QR.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting include logo: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }

  /// Get QR logo type (atlas logo, initials, or profile image)
  /// Returns [QrLogoType.atlasLogo] if not set or on error
  static Future<QrLogoType> getQrLogoType() async {
    await _ensureInitialized();

    try {
      final value = _prefs?.getInt(_qrLogoTypeKey);
      if (value == null) {
        return QrLogoType.atlasLogo; // Default to Atlas logo
      }
      return QrLogoType.fromValue(value);
    } catch (e) {
      developer.log(
        '❌ Error getting QR logo type: $e',
        name: 'QR.Settings',
        error: e
      );
      return QrLogoType.atlasLogo;
    }
  }

  /// Set QR logo type
  static Future<void> setQrLogoType(QrLogoType type) async {
    await _ensureInitialized();

    try {
      await _prefs?.setInt(_qrLogoTypeKey, type.value);
      developer.log(
        '✅ QR logo type set to: ${type.label}',
        name: 'QR.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting QR logo type: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }

  /// Get QR color mode (0 = black/white, 1 = colored)
  /// Returns 0 (black/white) by default for better scanning
  static Future<int> getColorMode() async {
    await _ensureInitialized();

    try {
      return _prefs?.getInt(_qrColorModeKey) ?? 0;
    } catch (e) {
      developer.log(
        '❌ Error getting color mode: $e',
        name: 'QR.Settings',
        error: e
      );
      return 0;
    }
  }

  /// Set QR color mode
  static Future<void> setColorMode(int mode) async {
    await _ensureInitialized();

    try {
      await _prefs?.setInt(_qrColorModeKey, mode);
      final modeName = mode == 0 ? 'Black & White' : 'Colored';
      developer.log(
        '✅ Color mode set to: $modeName',
        name: 'QR.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting color mode: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }

  /// Get QR payload type (0 = vCard, 1 = URL)
  /// Returns 0 (vCard) by default for maximum compatibility
  static Future<int> getPayloadType() async {
    await _ensureInitialized();

    try {
      return _prefs?.getInt(_qrPayloadTypeKey) ?? 0;
    } catch (e) {
      developer.log(
        '❌ Error getting payload type: $e',
        name: 'QR.Settings',
        error: e
      );
      return 0;
    }
  }

  /// Set QR payload type
  static Future<void> setPayloadType(int type) async {
    await _ensureInitialized();

    try {
      await _prefs?.setInt(_qrPayloadTypeKey, type);
      final typeName = type == 0 ? 'vCard' : 'Web Link';
      developer.log(
        '✅ Payload type set to: $typeName',
        name: 'QR.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting payload type: $e',
        name: 'QR.Settings',
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

  /// Helper to get error correction level name
  static String _getErrorCorrectionLevelName(int level) {
    switch (level) {
      case QrErrorCorrectLevel.L:
        return 'Low (~7%)';
      case QrErrorCorrectLevel.M:
        return 'Medium (~15%)';
      case QrErrorCorrectLevel.Q:
        return 'Quartile (~25%)';
      case QrErrorCorrectLevel.H:
        return 'High (~30%)';
      default:
        return 'Unknown';
    }
  }

  /// Get QR border color (for custom styling)
  /// Returns null if not set (will use default deep purple)
  static Future<int?> getBorderColor() async {
    await _ensureInitialized();

    try {
      return _prefs?.getInt(_qrBorderColorKey);
    } catch (e) {
      developer.log(
        '❌ Error getting border color: $e',
        name: 'QR.Settings',
        error: e
      );
      return null;
    }
  }

  /// Set QR border color
  static Future<void> setBorderColor(int colorValue) async {
    await _ensureInitialized();

    try {
      await _prefs?.setInt(_qrBorderColorKey, colorValue);
      developer.log(
        '✅ Border color set',
        name: 'QR.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting border color: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }

  /// Get user initials for QR center logo
  /// Returns null if not set
  static Future<String?> getInitials() async {
    await _ensureInitialized();

    try {
      return _prefs?.getString(_qrInitialsKey);
    } catch (e) {
      developer.log(
        '❌ Error getting initials: $e',
        name: 'QR.Settings',
        error: e
      );
      return null;
    }
  }

  /// Set user initials for QR center logo
  static Future<void> setInitials(String initials) async {
    await _ensureInitialized();

    try {
      await _prefs?.setString(_qrInitialsKey, initials.toUpperCase());
      developer.log(
        '✅ Initials set to: $initials',
        name: 'QR.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting initials: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }

  /// Get whether to show initials in QR center
  /// Returns false by default (recommended for best scanning)
  static Future<bool> getShowInitials() async {
    await _ensureInitialized();

    try {
      return _prefs?.getBool(_qrShowInitialsKey) ?? false;
    } catch (e) {
      developer.log(
        '❌ Error getting show initials setting: $e',
        name: 'QR.Settings',
        error: e
      );
      return false;
    }
  }

  /// Set whether to show initials in QR center
  static Future<void> setShowInitials(bool show) async {
    await _ensureInitialized();

    try {
      await _prefs?.setBool(_qrShowInitialsKey, show);
      developer.log(
        '✅ Show initials ${show ? 'enabled' : 'disabled'}',
        name: 'QR.Settings'
      );
    } catch (e) {
      developer.log(
        '❌ Error setting show initials: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }

  /// Extract initials from full name (e.g., "John Doe" → "JD")
  static String extractInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '';

    if (parts.length == 1) {
      // Single name: take first character
      return parts[0].substring(0, 1).toUpperCase();
    }

    // Multiple names: take first character of first and last name
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Reset all settings to defaults (for testing/debugging)
  static Future<void> resetToDefaults() async {
    await _ensureInitialized();

    try {
      await _prefs?.remove(_qrSizeKey);
      await _prefs?.remove(_qrErrorCorrectionKey);
      await _prefs?.remove(_qrIncludeLogoKey);
      await _prefs?.remove(_qrColorModeKey);
      await _prefs?.remove(_qrBorderColorKey);
      await _prefs?.remove(_qrInitialsKey);
      await _prefs?.remove(_qrShowInitialsKey);
      await _prefs?.remove(_qrLogoTypeKey);
      await _prefs?.remove(_qrPayloadTypeKey);
      developer.log('🔄 QR settings reset to defaults', name: 'QR.Settings');
    } catch (e) {
      developer.log(
        '❌ Error resetting QR settings: $e',
        name: 'QR.Settings',
        error: e
      );
    }
  }
}
