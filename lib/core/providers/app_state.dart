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
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Global app state provider for navigation and authentication flow
class AppState extends ChangeNotifier {
  // ========== Private State Variables ==========

  /// Whether this is the user's first time launching the app
  bool _isFirstLaunch = true;

  /// Whether the user has completed the onboarding tutorial
  bool _hasCompletedOnboarding = false;

  /// Whether the user is authenticated (for future Firebase auth)
  bool _isAuthenticated = false;

  /// Current user ID (for future Firebase integration)
  String? _currentUserId;

  /// Whether user has shared or received a card (for tutorial flow)
  bool _hasSharedOrReceived = false;

  /// Whether the state has been initialized from storage
  bool _isInitialized = false;

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
  /// TODO: Firebase - Integrate with Firebase Auth
  /// @param value Whether user is authenticated
  /// @param userId User's unique identifier (Firebase UID)
  void setAuthenticated(bool value, [String? userId]) {
    developer.log(
      value
        ? '🔐 User authenticated: $userId'
        : '🔓 User logged out',
      name: 'AppState.Auth',
    );

    _isAuthenticated = value;
    _currentUserId = userId;
    _saveState();
    notifyListeners();
  }

  /// Sign out current user
  ///
  /// TODO: Firebase - Call FirebaseAuth.signOut()
  void signOut() {
    developer.log(
      '👋 User signing out - Clearing auth state',
      name: 'AppState.Auth',
    );

    _isAuthenticated = false;
    _currentUserId = null;
    _saveState();
    notifyListeners();
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