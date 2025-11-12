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
      print('[GOOGLE] 🔵 Starting Google Sign-In flow...');

      // Initialize Google Sign-In with required scopes
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Trigger the Google account picker
      print('[GOOGLE] 📱 Showing Google account picker...');

      final googleUser = await googleSignIn.signIn();

      // User cancelled the sign-in
      if (googleUser == null) {
        print('[GOOGLE] ❌ Google Sign-In cancelled by user');
        return null;
      }

      print('[GOOGLE] ✅ Google account selected: ${googleUser.email}');

      // Obtain Google authentication tokens
      print('[GOOGLE] 🔑 Retrieving Google authentication tokens...');

      final googleAuth = await googleUser.authentication;

      print('[GOOGLE] ✅ Google tokens retrieved');
      print('[GOOGLE]    • Access Token: ${googleAuth.accessToken != null ? "present" : "null"}');
      print('[GOOGLE]    • ID Token: ${googleAuth.idToken != null ? "present" : "null"}');

      // Create Firebase credential from Google tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('[GOOGLE] 🔐 Signing in to Firebase with Google credential...');

      // Sign in to Firebase with the Google credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      print('[GOOGLE] ✅ Firebase sign-in successful');
      print('[GOOGLE]    • Email: ${userCredential.user?.email}');
      print('[GOOGLE]    • UID: ${userCredential.user?.uid}');
      print('[GOOGLE]    • Display Name: ${userCredential.user?.displayName}');

      return userCredential;

    } on FirebaseAuthException catch (e, stackTrace) {
      print('[GOOGLE] ❌ Firebase authentication error: ${e.code}');
      print('[GOOGLE]    Message: ${e.message}');
      print('[GOOGLE]    Stack trace: $stackTrace');

      rethrow; // Let the UI handle Firebase-specific errors

    } catch (e, stackTrace) {
      print('[GOOGLE] ❌ Google Sign-In error: $e');
      print('[GOOGLE]    Type: ${e.runtimeType}');
      print('[GOOGLE]    Stack trace: $stackTrace');

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
