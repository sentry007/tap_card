/// Firebase Auth Repository Implementation
///
/// Implements authentication using Firebase Auth
library;

import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_repository.dart';

/// Repository implementation using Firebase Authentication
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<UserCredential> signInAnonymously() async {
    try {
      developer.log(
        '🔐 Signing in anonymously...',
        name: 'FirebaseAuthRepo.SignInAnon',
      );

      final userCredential = await _auth.signInAnonymously();

      developer.log(
        '✅ Anonymous sign-in successful\n'
        '   • UID: ${userCredential.user?.uid}',
        name: 'FirebaseAuthRepo.SignInAnon',
      );

      return userCredential;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Anonymous sign-in failed',
        name: 'FirebaseAuthRepo.SignInAnon',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      developer.log(
        '🔐 Starting Google Sign-In flow...',
        name: 'FirebaseAuthRepo.SignInGoogle',
      );

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        developer.log(
          '⚠️  Google Sign-In cancelled by user',
          name: 'FirebaseAuthRepo.SignInGoogle',
        );
        throw Exception('Google Sign-In cancelled');
      }

      developer.log(
        'ℹ️  Google account selected: ${googleUser.email}',
        name: 'FirebaseAuthRepo.SignInGoogle',
      );

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      developer.log(
        '🔑 Google credentials obtained, signing in to Firebase...',
        name: 'FirebaseAuthRepo.SignInGoogle',
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      developer.log(
        '✅ Google Sign-In successful\n'
        '   • UID: ${userCredential.user?.uid}\n'
        '   • Email: ${userCredential.user?.email}\n'
        '   • Display Name: ${userCredential.user?.displayName}',
        name: 'FirebaseAuthRepo.SignInGoogle',
      );

      return userCredential;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Google Sign-In failed',
        name: 'FirebaseAuthRepo.SignInGoogle',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      developer.log(
        '🚪 Signing out...',
        name: 'FirebaseAuthRepo.SignOut',
      );

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);

      developer.log(
        '✅ Sign-out successful',
        name: 'FirebaseAuthRepo.SignOut',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Sign-out failed',
        name: 'FirebaseAuthRepo.SignOut',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      developer.log(
        '🗑️  Deleting account: ${user.uid}',
        name: 'FirebaseAuthRepo.DeleteAccount',
      );

      await user.delete();

      developer.log(
        '✅ Account deleted successfully',
        name: 'FirebaseAuthRepo.DeleteAccount',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Account deletion failed',
        name: 'FirebaseAuthRepo.DeleteAccount',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<UserCredential> linkWithGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      developer.log(
        '🔗 Linking anonymous account with Google...',
        name: 'FirebaseAuthRepo.LinkGoogle',
      );

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        developer.log(
          '⚠️  Google Sign-In cancelled by user',
          name: 'FirebaseAuthRepo.LinkGoogle',
        );
        throw Exception('Google Sign-In cancelled');
      }

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Link the accounts
      final userCredential = await user.linkWithCredential(credential);

      developer.log(
        '✅ Account linking successful\n'
        '   • UID: ${userCredential.user?.uid}\n'
        '   • Email: ${userCredential.user?.email}',
        name: 'FirebaseAuthRepo.LinkGoogle',
      );

      return userCredential;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Account linking failed',
        name: 'FirebaseAuthRepo.LinkGoogle',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
