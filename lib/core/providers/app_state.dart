/// Global Application State Provider
///
/// Manages app-wide state including onboarding flow, authentication status,
/// and user navigation state. Uses SharedPreferences for persistence.
///
/// State Flow:
/// 1. First Launch → Splash Screen
/// 2. After Splash → Onboarding (if not completed)
/// 3. After Onboarding → Main App (Home Screen)
///
/// TODO: Firebase - Sync authentication state with Firebase Auth
/// TODO: Firebase - Store user preferences in Firestore
library;

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

/// Global app state provider for navigation and authentication flow
class AppState extends ChangeNotifier {
  // ========== Private State Variables ==========

  /// Whether this is the user's first time launching the app
  bool _isFirstLaunch = true;

  /// Whether the user has completed the onboarding tutorial
  bool _hasCompletedOnboarding = false;

  /// Whether the user is authenticated (synced with Firebase Auth)
  bool _isAuthenticated = false;

  /// Current user ID (Firebase Auth UID)
  String? _currentUserId;

  /// Whether user has shared or received a card (for tutorial flow)
  bool _hasSharedOrReceived = false;

  /// Whether the state has been initialized from storage
  bool _isInitialized = false;

  /// Auth service instance
  final AuthService _authService = AuthService();

  /// Profile service instance
  final ProfileService _profileService = ProfileService();

  /// Constructor - Set up Firebase Auth listener
  AppState() {
    _initializeAuthListener();
    _initializeProfileListener();
  }

  /// Initialize Firebase Auth state listener
  ///
  /// Syncs authentication state with Firebase Auth in real-time
  /// Also coordinates ProfileService to ensure profiles match auth state
  void _initializeAuthListener() {
    _authService.authStateChanges.listen((User? user) {
      // Call async handler without awaiting (stream listener can't be async)
      _handleAuthStateChange(user);
    });

    print('[APP] 👂 Firebase Auth listener initialized with ProfileService coordination');
  }

  /// Handle auth state changes asynchronously
  ///
  /// Separated from listener to properly handle async operations
  Future<void> _handleAuthStateChange(User? user) async {
    final startTime = DateTime.now();
    final wasAuthenticated = _isAuthenticated;
    final previousUserId = _currentUserId;

    _isAuthenticated = user != null;
    _currentUserId = user?.uid;

    print(
      user != null
          ? '[APP] 🔐 Auth state changed: User signed in (${user.isAnonymous ? "Guest" : _authService.authProviderName}) - UID: ${user.uid}'
          : '[APP] 🔓 Auth state changed: User signed out',
    );
    print('[APP]    • wasAuthenticated: $wasAuthenticated → _isAuthenticated: $_isAuthenticated');
    print('[APP]    • previousUserId: $previousUserId → _currentUserId: $_currentUserId');
    print('[APP]    • State change detected: ${wasAuthenticated != _isAuthenticated || previousUserId != _currentUserId}');

    // Coordinate ProfileService when needed
    // Always ensure profiles exist when user is authenticated, even if auth state didn't change
    // This handles cases where Firebase restores session before we initialize
    try {
      if (_isAuthenticated && user != null) {
        // User is signed in - ensure profiles exist and match UID
        print('[APP] 🔄 Starting profile coordination...');

        final profileStartTime = DateTime.now();
        await ProfileService().ensureProfilesExist();
        final profileDuration = DateTime.now().difference(profileStartTime).inMilliseconds;

        print('[APP] ✅ Profile coordination complete (${profileDuration}ms)');
      } else if (!_isAuthenticated && wasAuthenticated) {
        // User signed out - clear all profiles
        print('[APP] 🗑️  User signed out - clearing all profiles...');
        await ProfileService().clearAllProfiles();
        print('[APP] ✅ Profiles cleared successfully');
      } else if (!_isAuthenticated && !wasAuthenticated) {
        print('[APP] ℹ️  No user signed in - no coordination needed');
      }

      await _saveState();

      final totalDuration = DateTime.now().difference(startTime).inMilliseconds;
      print('[APP] ✅ Auth state handling complete (${totalDuration}ms total)');

      // ✅ CRITICAL: Defer notifyListeners to next frame to avoid Navigator lock conflicts
      // This prevents router redirects from happening during active widget transitions
      SchedulerBinding.instance.addPostFrameCallback((_) {
        print('[APP] 📢 Notifying listeners (deferred) - router will now check redirects');
        notifyListeners();
      });
    } catch (e, stackTrace) {
      print('[APP] ❌ ERROR in auth state handling: $e');
      print('[APP] Stack trace: $stackTrace');

      // Still update state and notify even if coordination failed
      await _saveState();

      // Defer notification to avoid Navigator conflicts during error handling too
      SchedulerBinding.instance.addPostFrameCallback((_) {
        print('[APP] 📢 Notifying listeners after error (deferred)');
        notifyListeners();
      });
    }
  }

  /// Initialize ProfileService listener
  ///
  /// Listens to profile changes and notifies router when profiles are ready
  void _initializeProfileListener() {
    _profileService.addListener(() {
      // When profiles change, notify router to re-evaluate routes
      notifyListeners();
    });

    developer.log(
      '👂 ProfileService listener initialized',
      name: 'AppState.Init',
    );
  }

  // ========== Public Getters ==========

  /// Returns true if this is the first app launch
  bool get isFirstLaunch => _isFirstLaunch;

  /// Returns true if user has completed onboarding
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  /// Returns true if user is authenticated (TODO: Firebase Auth)
  bool get isAuthenticated => _isAuthenticated;

  /// Current user ID (TODO: Firebase Auth UID)
  String? get currentUserId => _currentUserId;

  /// Returns true if user has performed first share/receive
  bool get hasSharedOrReceived => _hasSharedOrReceived;

  /// Returns true if state has been loaded from storage
  bool get isInitialized => _isInitialized;

  // ========== Computed Navigation Properties ==========

  /// Should show splash screen (only on first launch)
  bool get shouldShowSplash => _isFirstLaunch && _isInitialized;

  /// Should show onboarding flow
  bool get shouldShowOnboarding => !_hasCompletedOnboarding && _isInitialized;

  /// Can access main app features
  bool get canAccessMainApp => _hasCompletedOnboarding && _isInitialized;

  /// Whether auth and profiles are both ready for navigation decisions
  ///
  /// This is the single source of truth for router redirect logic.
  /// Prevents race conditions by ensuring both auth state and profiles are loaded.
  bool get isAuthAndProfilesReady {
    // Must be initialized first
    if (!_isInitialized) return false;

    // If not authenticated, we're ready (will show splash)
    if (!_isAuthenticated) return true;

    // If authenticated, must wait for profiles to load
    return ProfileService().isLoaded;
  }

  // ========== State Update Methods ==========

  /// Mark splash screen as completed
  ///
  /// Called when user exits splash screen after first launch
  void completeSplash() {
    developer.log(
      '✅ Splash completed - Moving to next flow step',
      name: 'AppState.Flow',
    );

    _isFirstLaunch = false;
    _saveState();
    notifyListeners();
  }

  /// Complete splash without marking onboarding as done
  ///
  /// Used for guest users who should see onboarding every time
  void completeSplashForGuest() {
    developer.log(
      '👤 Guest user - Completing splash, will show onboarding',
      name: 'AppState.Flow',
    );

    _isFirstLaunch = false;
    // DON'T mark onboarding as complete for guests
    _saveState();
    notifyListeners();
  }

  /// Mark that user has shared or received their first card
  ///
  /// Used for tracking tutorial completion and user engagement
  void markSharedOrReceived() {
    developer.log(
      '🎉 User performed first share/receive action',
      name: 'AppState.Action',
    );

    _hasSharedOrReceived = true;
    _saveState();
    notifyListeners();
  }

  /// Mark onboarding as completed
  ///
  /// Allows user to access main app features
  void completeOnboarding() {
    developer.log(
      '✅ Onboarding completed - User can now access main app',
      name: 'AppState.Flow',
    );

    _hasCompletedOnboarding = true;
    _saveState();
    notifyListeners();
  }

  /// Set user authentication status
  ///
  /// Note: Auth state is automatically synced via Firebase Auth listener
  /// This method is kept for backward compatibility but auth changes
  /// should happen through AuthService methods (signInAnonymously, etc.)
  void setAuthenticated(bool value, [String? userId]) {
    developer.log(
      '⚠️  setAuthenticated called - Auth state should be managed by Firebase Auth',
      name: 'AppState.Auth',
    );

    // Auth state is now managed by Firebase Auth listener
    // This method is deprecated but kept for compatibility
  }

  /// Sign out current user
  ///
  /// Calls Firebase Auth to sign out, which will trigger auth state listener
  Future<void> signOut() async {
    print('[APP] 👋 signOut() called - starting sign-out process');

    try {
      print('[APP] 🔄 Calling AuthService.signOut()...');
      await _authService.signOut();
      print('[APP] ✅ AuthService.signOut() completed');
      print('[APP] 👉 Auth state listener will handle profile cleanup and navigation');
      // Auth state will be updated automatically by listener
    } catch (e, stackTrace) {
      print('[APP] ❌ Error signing out: $e');
      print('[APP] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Reset all app state to initial values
  ///
  /// Used for testing or when user wants to restart onboarding
  /// ⚠️ WARNING: This clears all local preferences
  void resetAppState() {
    developer.log(
      '⚠️  Resetting all app state - User will see onboarding again',
      name: 'AppState.Reset',
    );

    _isFirstLaunch = true;
    _hasCompletedOnboarding = false;
    _isAuthenticated = false;
    _currentUserId = null;
    _hasSharedOrReceived = false;
    _saveState();
    notifyListeners();
  }

  /// Skip onboarding and go directly to main app
  ///
  /// For experienced users or testing purposes
  void skipToMainApp() {
    developer.log(
      '⏭️  Skipping onboarding - Direct access to main app',
      name: 'AppState.Flow',
    );

    _hasCompletedOnboarding = true;
    _isFirstLaunch = false;
    _saveState();
    notifyListeners();
  }

  // ========== Persistence Methods ==========

  /// Initialize app state from persistent storage
  ///
  /// Loads saved preferences from SharedPreferences. Called once on app startup.
  /// TODO: Firebase - Also fetch user state from Firestore if authenticated
  Future<void> initializeFromStorage() async {
    final startTime = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load all saved preferences
      _isFirstLaunch = prefs.getBool(StorageKeys.isFirstLaunch) ?? true;
      _hasCompletedOnboarding = prefs.getBool(StorageKeys.hasCompletedOnboarding) ?? false;
      _isAuthenticated = prefs.getBool(StorageKeys.isAuthenticated) ?? false;
      _currentUserId = prefs.getString(StorageKeys.currentUserId);
      _hasSharedOrReceived = prefs.getBool(StorageKeys.hasSharedOrReceived) ?? false;

      _isInitialized = true;

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '📱 AppState initialized in ${duration}ms\n'
        '   • First Launch: $_isFirstLaunch\n'
        '   • Onboarding Complete: $_hasCompletedOnboarding\n'
        '   • Has Shared/Received: $_hasSharedOrReceived\n'
        '   • Authenticated: $_isAuthenticated',
        name: 'AppState.Init',
      );

      // TODO: Firebase - Sync with Firestore if authenticated
      // if (_isAuthenticated && _currentUserId != null) {
      //   await _syncWithFirestore();
      // }

      notifyListeners();

    } catch (e, stackTrace) {
      developer.log(
        '❌ Error initializing AppState',
        name: 'AppState.Init',
        error: e,
        stackTrace: stackTrace,
      );

      // Even on error, mark as initialized with defaults
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Save current state to persistent storage
  ///
  /// Called after every state change to persist user preferences
  /// TODO: Firebase - Also sync to Firestore if authenticated
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save all state values
      await Future.wait([
        prefs.setBool(StorageKeys.isFirstLaunch, _isFirstLaunch),
        prefs.setBool(StorageKeys.hasCompletedOnboarding, _hasCompletedOnboarding),
        prefs.setBool(StorageKeys.isAuthenticated, _isAuthenticated),
        prefs.setBool(StorageKeys.hasSharedOrReceived, _hasSharedOrReceived),
      ]);

      // Save user ID if present
      if (_currentUserId != null) {
        await prefs.setString(StorageKeys.currentUserId, _currentUserId!);
      } else {
        await prefs.remove(StorageKeys.currentUserId);
      }

      developer.log(
        '💾 AppState saved to storage',
        name: 'AppState.Save',
      );

      // TODO: Firebase - Sync to Firestore
      // if (_isAuthenticated && _currentUserId != null) {
      //   await _syncToFirestore();
      // }

    } catch (e, stackTrace) {
      developer.log(
        '❌ Error saving AppState',
        name: 'AppState.Save',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // TODO: Firebase - Implement Firestore sync methods
  // Future<void> _syncWithFirestore() async { }
  // Future<void> _syncToFirestore() async { }
}

/// App navigation flow states
///
/// Defines the possible navigation states for the app
enum AppFlow {
  /// Initial splash screen (first launch only)
  splash,

  /// Onboarding tutorial flow
  onboarding,

  /// Main app features (home, profile, etc.)
  main,
}