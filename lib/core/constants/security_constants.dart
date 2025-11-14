/// Security Constants
///
/// Centralized security configuration for the entire app
/// All size limits, allowed types, and security thresholds
class SecurityConstants {
  SecurityConstants._(); // Prevent instantiation

  // ====================
  // Input Size Limits
  // ====================

  static const int maxNameLength = 100;
  static const int maxEmailLength = 255;
  static const int maxPhoneLength = 20;
  static const int maxUrlLength = 2048;
  static const int maxNfcPayloadSize = 10240; // 10KB

  // ====================
  // File Upload Limits
  // ====================

  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB

  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static const List<String> allowedImageMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];

  // ====================
  // Rate Limits (per user per minute)
  // ====================

  static const int maxProfileUpdatesPerMinute = 10;
  static const int maxImageUploadsPerHour = 20;
  static const int maxFirestoreReadsPerMinute = 50;
  static const int maxFirestoreWritesPerMinute = 20;

  // Rate limit configuration for RateLimiter service
  static final Map<String, Map<String, dynamic>> rateLimitConfig = {
    'profile_update': {
      'maxRequests': maxProfileUpdatesPerMinute,
      'window': const Duration(minutes: 1),
      'lockoutDuration': const Duration(minutes: 5),
    },
    'image_upload': {
      'maxRequests': maxImageUploadsPerHour,
      'window': const Duration(hours: 1),
      'lockoutDuration': const Duration(hours: 1),
    },
    'firestore_read': {
      'maxRequests': maxFirestoreReadsPerMinute,
      'window': const Duration(minutes: 1),
      'lockoutDuration': const Duration(minutes: 2),
    },
    'firestore_write': {
      'maxRequests': maxFirestoreWritesPerMinute,
      'window': const Duration(minutes: 1),
      'lockoutDuration': const Duration(minutes: 5),
    },
    'nfc_write': {
      'maxRequests': 5,
      'window': const Duration(minutes: 1),
      'lockoutDuration': const Duration(minutes: 5),
    },
    'nfc_read': {
      'maxRequests': 30,
      'window': const Duration(minutes: 1),
      'lockoutDuration': const Duration(minutes: 2),
    },
  };

  // ====================
  // Session Security
  // ====================

  static const Duration sessionTimeout = Duration(hours: 24);
  static const Duration tokenRefreshInterval = Duration(hours: 1);

  // ====================
  // Content Security Policy
  // ====================

  static const Map<String, String> securityHeaders = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  };

  // ====================
  // Validation Patterns
  // ====================

  // Email regex (RFC 5322 simplified)
  static const String emailPattern =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  // Phone regex (international format)
  static const String phonePattern = r'^\+?[\d]{10,15}$';

  // Name regex (alphanumeric + safe punctuation)
  static const String namePattern = r"^[a-zA-Z0-9\s\-'\.]+$";

  // URL regex (http/https only)
  static const String urlPattern = r'^https?://[^\s/$.?#].[^\s]*$';
}
