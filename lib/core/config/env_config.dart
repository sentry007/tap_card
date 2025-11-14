import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment Configuration
/// Loads and provides access to environment variables from .env file
class EnvConfig {
  // Singleton pattern
  static final EnvConfig _instance = EnvConfig._internal();
  factory EnvConfig() => _instance;
  EnvConfig._internal();

  /// Initialize environment configuration
  /// Call this before runApp() in main.dart
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('✅ Environment variables loaded successfully');
    } catch (e) {
      debugPrint('⚠️ Could not load .env file: $e');
      debugPrint('Using default configuration');
    }
  }

  // ================================
  // Firebase Configuration
  // ================================

  static String get firebaseApiKey =>
      dotenv.env['FIREBASE_API_KEY'] ?? _throwMissingEnvVar('FIREBASE_API_KEY');

  static String get firebaseAppId =>
      dotenv.env['FIREBASE_APP_ID'] ?? _throwMissingEnvVar('FIREBASE_APP_ID');

  static String get firebaseMessagingSenderId =>
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ??
      _throwMissingEnvVar('FIREBASE_MESSAGING_SENDER_ID');

  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ??
      _throwMissingEnvVar('FIREBASE_PROJECT_ID');

  static String get firebaseStorageBucket =>
      dotenv.env['FIREBASE_STORAGE_BUCKET'] ??
      _throwMissingEnvVar('FIREBASE_STORAGE_BUCKET');

  // ================================
  // Environment
  // ================================

  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';

  static bool get isDevelopment => appEnv == 'development';
  static bool get isStaging => appEnv == 'staging';
  static bool get isProduction => appEnv == 'production';

  // ================================
  // API Configuration
  // ================================

  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080';

  // ================================
  // Security
  // ================================

  static bool get enforceHttps =>
      dotenv.env['ENFORCE_HTTPS']?.toLowerCase() == 'true';

  static bool get enableRateLimiting =>
      dotenv.env['ENABLE_RATE_LIMITING']?.toLowerCase() != 'false'; // Default true

  static bool get enableDebugLogging =>
      dotenv.env['ENABLE_DEBUG_LOGGING']?.toLowerCase() != 'false'; // Default true in dev

  // ================================
  // Error Tracking (Optional)
  // ================================

  static String? get sentryDsn => dotenv.env['SENTRY_DSN'];

  static bool get hasSentry => sentryDsn != null && sentryDsn!.isNotEmpty;

  // ================================
  // Feature Flags (Optional)
  // ================================

  static bool get featureNfcEnabled =>
      dotenv.env['FEATURE_NFC_ENABLED']?.toLowerCase() != 'false'; // Default true

  static bool get featureAnalyticsEnabled =>
      dotenv.env['FEATURE_ANALYTICS_ENABLED']?.toLowerCase() == 'true';

  static bool get featureOfflineModeEnabled =>
      dotenv.env['FEATURE_OFFLINE_MODE_ENABLED']?.toLowerCase() != 'false'; // Default true

  // ================================
  // Helpers
  // ================================

  /// Throws an error if a required environment variable is missing
  static String _throwMissingEnvVar(String key) {
    throw StateError(
      'Missing required environment variable: $key\n'
      'Make sure you have a .env file with all required variables.\n'
      'See .env.example for reference.',
    );
  }

  /// Get all environment variables (for debugging only)
  static Map<String, String> getAllEnvVars() {
    if (!enableDebugLogging) {
      throw StateError('getAllEnvVars() can only be called in debug mode');
    }
    return dotenv.env;
  }

  /// Print configuration summary (for debugging)
  static void printConfig() {
    if (!enableDebugLogging) return;

    debugPrint('=================================');
    debugPrint('Environment Configuration');
    debugPrint('=================================');
    debugPrint('Environment: $appEnv');
    debugPrint('Debug Logging: $enableDebugLogging');
    debugPrint('Rate Limiting: $enableRateLimiting');
    debugPrint('Enforce HTTPS: $enforceHttps');
    debugPrint('NFC Enabled: $featureNfcEnabled');
    debugPrint('Analytics Enabled: $featureAnalyticsEnabled');
    debugPrint('Offline Mode: $featureOfflineModeEnabled');
    debugPrint('Sentry Enabled: $hasSentry');
    debugPrint('=================================');
  }
}
