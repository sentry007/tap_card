/// Firebase Authentication Service
///
/// Singleton service that manages Firebase Authentication state and operations.
/// Provides a simplified interface for authentication throughout the app.
///
/// Features:
/// - Real-time auth state stream
/// - Anonymous (guest) sign-in
/// - Sign out functionality
/// - Account deletion
/// - Guest account linking to real providers
library;

import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/auth/google_sign_in_helper.dart';
import '../../utils/logger.dart';

/// Authentication service wrapping Firebase Auth
///
/// Simple wrapper around Firebase Auth - does NOT listen to auth state.
/// AppState is responsible for listening and coordinating state changes.
class AuthService {
  // ========== Singleton Pattern ==========

  static final AuthService _instance = AuthService._internal();

  /// Get the singleton instance
  factory AuthService() => _instance;

  AuthService._internal() {
    Logger.info(
      'AuthService initialized (wrapper only, no listener)\n'
      '  Signed in: $isSignedIn\n'
      '  Anonymous: $isAnonymous\n'
      '  Provider: $authProviderName\n'
      '  UID: ${uid ?? "none"}',
      name: 'AUTH',
    );
  }

  // ========== Private State ==========

  /// Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== Public Getters ==========

  /// Stream of authentication state changes
  ///
  /// Emits whenever user signs in, signs out, or token refreshes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream that includes user profile changes
  ///
  /// More comprehensive than authStateChanges, includes profile updates
  Stream<User?> get userChanges => _auth.userChanges();

  /// Current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Whether a user is currently signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Whether the current user is anonymous (guest)
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Current user's unique ID
  String? get uid => _auth.currentUser?.uid;

  /// Current user's email (null for anonymous/phone users)
  String? get email => _auth.currentUser?.email;

  /// Current user's phone number (null for email/anonymous users)
  String? get phoneNumber => _auth.currentUser?.phoneNumber;

  /// Get display name for current user
  ///
  /// Returns email, phone, or "Guest" depending on auth method
  String get displayName {
    final user = _auth.currentUser;
    if (user == null) return 'Not signed in';

    if (user.isAnonymous) return 'Guest User';
    if (user.email != null) return user.email!;
    if (user.phoneNumber != null) return user.phoneNumber!;

    return 'User';
  }

  /// Get the authentication provider type
  ///
  /// Returns: 'phone', 'google.com', 'password', 'anonymous', etc.
  String get authProviderType {
    final user = _auth.currentUser;
    if (user == null) return 'none';

    if (user.isAnonymous) return 'anonymous';

    // Get the first provider (most users have one)
    if (user.providerData.isNotEmpty) {
      return user.providerData.first.providerId;
    }

    return 'unknown';
  }

  /// Get a user-friendly auth provider name
  String get authProviderName {
    switch (authProviderType) {
      case 'phone':
        return 'Phone';
      case 'google.com':
        return 'Google';
      case 'apple.com':
        return 'Apple';
      case 'password':
        return 'Email';
      case 'anonymous':
        return 'Guest';
      default:
        return 'Unknown';
    }
  }

  // ========== Authentication Methods ==========
  // Note: Auth state listening is handled by AppState, not AuthService

  // ========== Authentication Methods ==========

  /// Sign in anonymously as a guest
  ///
  /// Creates a temporary Firebase user that can be linked to a real account later
  /// Returns the created User or null if sign-in failed
  Future<User?> signInAnonymously() async {
    try {
      developer.log(
        '👤 Signing in anonymously...',
        name: 'AuthService.SignIn',
      );

      final userCredential = await _auth.signInAnonymously();

      developer.log(
        '✅ Anonymous sign-in successful\n'
        '   • UID: ${userCredential.user?.uid}',
        name: 'AuthService.SignIn',
      );

      return userCredential.user;

    } catch (e, stackTrace) {
      developer.log(
        '❌ Anonymous sign-in failed',
        name: 'AuthService.SignIn',
        error: e,
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  /// Sign out the current user
  ///
  /// Clears authentication state from both Firebase and Google (if applicable)
  /// AppState will automatically clear profiles via auth state listener
  /// Returns to sign-in screen after successful sign-out
  Future<void> signOut() async {
    try {
      final wasAnonymous = isAnonymous;
      final provider = authProviderName;

      developer.log(
        '🚪 Signing out user (${wasAnonymous ? "Guest" : provider})...',
        name: 'AuthService.SignOut',
      );

      // Sign out from Google first (if user signed in with Google)
      if (provider == 'Google') {
        developer.log(
          '🔄 Signing out from Google...',
          name: 'AuthService.SignOut',
        );
        await GoogleSignInHelper.signOut();
      }

      // Sign out from Firebase
      // AppState auth listener will automatically call ProfileService().clearAllProfiles()
      await _auth.signOut();

      developer.log(
        '✅ Sign out successful - AppState will handle profile cleanup',
        name: 'AuthService.SignOut',
      );

    } catch (e, stackTrace) {
      developer.log(
        '❌ Sign out failed',
        name: 'AuthService.SignOut',
        error: e,
        stackTrace: stackTrace,
      );

      rethrow; // Let the UI handle the error
    }
  }

  /// Delete the current user's account
  ///
  /// Permanently deletes the Firebase Auth account
  /// WARNING: This cannot be undone. Firestore data should be deleted separately
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      developer.log(
        '🗑️  Deleting user account...\n'
        '   • UID: ${user.uid}\n'
        '   • Provider: $authProviderName',
        name: 'AuthService.Delete',
      );

      await user.delete();

      developer.log(
        '✅ Account deleted successfully',
        name: 'AuthService.Delete',
      );

    } catch (e, stackTrace) {
      developer.log(
        '❌ Account deletion failed',
        name: 'AuthService.Delete',
        error: e,
        stackTrace: stackTrace,
      );

      rethrow; // Let the UI handle the error
    }
  }

  /// Link anonymous account to a credential
  ///
  /// Converts a guest account to a real account while preserving data
  /// This is handled automatically by firebase_ui_auth when user signs in
  /// from a guest account, but this method is here for manual linking if needed
  Future<UserCredential?> linkAnonymousAccount(AuthCredential credential) async {
    try {
      final user = _auth.currentUser;
      if (user == null || !user.isAnonymous) {
        throw Exception('No anonymous user to link');
      }

      developer.log(
        '🔗 Linking anonymous account to credential...',
        name: 'AuthService.Link',
      );

      final userCredential = await user.linkWithCredential(credential);

      developer.log(
        '✅ Account linked successfully\n'
        '   • New provider: ${userCredential.user?.providerData.first.providerId}',
        name: 'AuthService.Link',
      );

      return userCredential;

    } catch (e, stackTrace) {
      developer.log(
        '❌ Account linking failed',
        name: 'AuthService.Link',
        error: e,
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  /// Re-authenticate user (required before sensitive operations like delete account)
  ///
  /// Some operations require recent authentication. This prompts the user to sign in again.
  /// Returns true if re-authentication successful
  Future<bool> reauthenticate() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // For anonymous users, no re-auth needed
      if (user.isAnonymous) return true;

      // Re-authentication is typically handled by firebase_ui_auth
      // This is a placeholder for custom re-auth if needed
      developer.log(
        '🔐 Re-authentication required for this operation',
        name: 'AuthService.Reauth',
      );

      return true;

    } catch (e, stackTrace) {
      developer.log(
        '❌ Re-authentication failed',
        name: 'AuthService.Reauth',
        error: e,
        stackTrace: stackTrace,
      );

      return false;
    }
  }

  /// Reload current user data from Firebase
  ///
  /// Useful after updating user profile or linking accounts
  /// Note: This no longer notifies listeners - AppState handles state management
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();

      developer.log(
        '🔄 User data reloaded',
        name: 'AuthService.Reload',
      );

    } catch (e, stackTrace) {
      developer.log(
        '⚠️  Failed to reload user data',
        name: 'AuthService.Reload',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
