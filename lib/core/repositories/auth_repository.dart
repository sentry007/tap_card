/// Auth Repository Interface
///
/// Abstract repository for authentication operations
library;

import 'package:firebase_auth/firebase_auth.dart';

/// Abstract repository for authentication
abstract class AuthRepository {
  /// Get current user
  User? get currentUser;

  /// Get current user ID
  String? get uid;

  /// Check if user is signed in
  bool get isSignedIn;

  /// Check if user is anonymous
  bool get isAnonymous;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges;

  /// Sign in anonymously
  Future<UserCredential> signInAnonymously();

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle();

  /// Sign out
  Future<void> signOut();

  /// Delete account
  Future<void> deleteAccount();

  /// Link anonymous account with Google
  Future<UserCredential> linkWithGoogle();
}
