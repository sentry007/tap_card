/// Timeout Constants
///
/// Centralized timeout values for network operations, async operations,
/// and other time-sensitive features.
library;

/// Timeout constants for network and async operations
class TimeoutConstants {
  /// Timeout for Firebase Auth state restoration (in seconds)
  static const int authStateRestoreSeconds = 3;

  /// Timeout for Firestore read operations (in seconds)
  static const int firestoreReadSeconds = 10;

  /// Timeout for Firestore write operations (in seconds)
  static const int firestoreWriteSeconds = 15;

  /// Timeout for NFC session operations (in seconds)
  static const int nfcSessionSeconds = 30;

  /// Timeout for NFC write operations (in seconds)
  static const int nfcWriteSeconds = 10;

  /// Timeout for NFC read operations (in seconds)
  static const int nfcReadSeconds = 10;

  /// Timeout for image upload operations (in seconds)
  static const int imageUploadSeconds = 60;

  /// Timeout for network image loading (in seconds)
  static const int networkImageSeconds = 5;

  /// Timeout for QR code scan operations (in seconds)
  static const int qrScanSeconds = 30;

  /// Timeout for contact permission requests (in seconds)
  static const int permissionRequestSeconds = 10;

  /// General API request timeout (in seconds)
  static const int apiRequestSeconds = 15;

  /// Retry delay for failed operations (in milliseconds)
  static const int retryDelayMilliseconds = 1000;

  /// Maximum number of retry attempts for network operations
  static const int maxRetryAttempts = 3;
}
