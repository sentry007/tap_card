/// Google Sign-In Helper
///
/// Direct API wrapper for Google Sign-In without Firebase UI screens.
/// Provides a single method that handles the entire Google OAuth flow
/// and returns a Firebase UserCredential.
///
/// Features:
/// - Direct google_sign_in API integration
/// - No intermediate screens - just the Google popup
/// - Automatic Firebase credential creation
/// - Comprehensive error handling and logging
library;

import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../utils/logger.dart';

/// Helper class for Google Sign-In authentication
class GoogleSignInHelper {
  GoogleSignInHelper._(); // Private constructor to prevent instantiation

  /// Sign in with Google using direct API
  ///
  /// Shows the Google account picker popup and returns Firebase UserCredential.
  /// This method handles the entire OAuth flow including:
  /// 1. Google account selection
  /// 2. OAuth token retrieval
  /// 3. Firebase credential creation
  /// 4. Firebase authentication
  ///
  /// Returns null if sign-in is cancelled or fails.
  /// Throws FirebaseAuthException for Firebase-specific errors.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      Logger.info('Starting Google Sign-In flow...', name: 'GOOGLE');

      // Initialize Google Sign-In with required scopes
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Trigger the Google account picker
      Logger.debug('Showing Google account picker...', name: 'GOOGLE');

      final googleUser = await googleSignIn.signIn();

      // User cancelled the sign-in
      if (googleUser == null) {
        Logger.info('Google Sign-In cancelled by user', name: 'GOOGLE');
        return null;
      }

      Logger.info('Google account selected: ${googleUser.email}', name: 'GOOGLE');

      // Obtain Google authentication tokens
      Logger.debug('Retrieving Google authentication tokens...', name: 'GOOGLE');

      final googleAuth = await googleUser.authentication;

      Logger.debug('Google tokens retrieved\n  Access Token: ${googleAuth.accessToken != null ? "present" : "null"}\n  ID Token: ${googleAuth.idToken != null ? "present" : "null"}', name: 'GOOGLE');

      // Create Firebase credential from Google tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      Logger.info('Signing in to Firebase with Google credential...', name: 'GOOGLE');

      // Sign in to Firebase with the Google credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      Logger.info('Firebase sign-in successful\n  Email: ${userCredential.user?.email}\n  UID: ${userCredential.user?.uid}\n  Display Name: ${userCredential.user?.displayName}', name: 'GOOGLE');

      return userCredential;

    } on FirebaseAuthException catch (e, stackTrace) {
      Logger.error('Firebase authentication error: ${e.code}\n  Message: ${e.message}', name: 'GOOGLE', error: e, stackTrace: stackTrace);

      rethrow; // Let the UI handle Firebase-specific errors

    } catch (e, stackTrace) {
      Logger.error('Google Sign-In error: $e\n  Type: ${e.runtimeType}', name: 'GOOGLE', error: e, stackTrace: stackTrace);

      return null;
    }
  }

  /// Sign out from Google account
  ///
  /// This signs out from both Google and Firebase.
  /// Call this when user wants to completely sign out.
  static Future<void> signOut() async {
    try {
      developer.log(
        '🚪 Signing out from Google...',
        name: 'GoogleSignIn.SignOut',
      );

      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      developer.log(
        '✅ Google sign-out successful',
        name: 'GoogleSignIn.SignOut',
      );

    } catch (e, stackTrace) {
      developer.log(
        '⚠️  Google sign-out error (non-critical)',
        name: 'GoogleSignIn.SignOut',
        error: e,
        stackTrace: stackTrace,
      );

      // Don't rethrow - Google sign-out errors are non-critical
      // Firebase sign-out will still work
    }
  }

  /// Disconnect Google account
  ///
  /// This revokes access and signs out from Google completely.
  /// More thorough than signOut() - use when deleting account.
  static Future<void> disconnect() async {
    try {
      developer.log(
        '🔌 Disconnecting Google account...',
        name: 'GoogleSignIn.Disconnect',
      );

      final googleSignIn = GoogleSignIn();
      await googleSignIn.disconnect();

      developer.log(
        '✅ Google account disconnected',
        name: 'GoogleSignIn.Disconnect',
      );

    } catch (e, stackTrace) {
      developer.log(
        '⚠️  Google disconnect error (non-critical)',
        name: 'GoogleSignIn.Disconnect',
        error: e,
        stackTrace: stackTrace,
      );

      // Don't rethrow - disconnect errors are non-critical
    }
  }
}
