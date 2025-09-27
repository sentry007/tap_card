import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  bool _isFirstLaunch = true;
  bool _hasCompletedOnboarding = false;
  bool _isAuthenticated = false;
  String? _currentUserId;
  bool _hasSharedOrReceived = false;
  bool _isInitialized = false;

  // Getters
  bool get isFirstLaunch => _isFirstLaunch;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  bool get hasSharedOrReceived => _hasSharedOrReceived;
  bool get isInitialized => _isInitialized;

  // Computed properties
  bool get shouldShowSplash => _isFirstLaunch && _isInitialized;
  bool get shouldShowOnboarding => !_hasCompletedOnboarding && _isInitialized;
  bool get canAccessMainApp => _hasCompletedOnboarding && _isInitialized;

  // Methods
  void completeSplash() {
    _isFirstLaunch = false;
    _saveState();
    notifyListeners();
  }

  void markSharedOrReceived() {
    _hasSharedOrReceived = true;
    _saveState();
    notifyListeners();
  }

  void completeOnboarding() {
    _hasCompletedOnboarding = true;
    _saveState();
    notifyListeners();
  }

  void setAuthenticated(bool value, [String? userId]) {
    _isAuthenticated = value;
    _currentUserId = userId;
    _saveState();
    notifyListeners();
  }

  void signOut() {
    _isAuthenticated = false;
    _currentUserId = null;
    _saveState();
    notifyListeners();
  }

  void resetAppState() {
    _isFirstLaunch = true;
    _hasCompletedOnboarding = false;
    _isAuthenticated = false;
    _currentUserId = null;
    _hasSharedOrReceived = false;
    _saveState();
    notifyListeners();
  }

  /// Skip onboarding and go directly to main app (for experienced users)
  void skipToMainApp() {
    _hasCompletedOnboarding = true;
    _isFirstLaunch = false;
    _saveState();
    notifyListeners();
  }

  /// Initialize app state from persistent storage
  Future<void> initializeFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
      _hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
      _isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      _currentUserId = prefs.getString('current_user_id');
      _hasSharedOrReceived = prefs.getBool('has_shared_or_received') ?? false;

      _isInitialized = true;

      print('📱 AppState initialized: firstLaunch=$_isFirstLaunch, onboarding=$_hasCompletedOnboarding, shared=$_hasSharedOrReceived');
      notifyListeners();

    } catch (e) {
      print('❌ Error initializing AppState: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Save current state to persistent storage
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('is_first_launch', _isFirstLaunch);
      await prefs.setBool('has_completed_onboarding', _hasCompletedOnboarding);
      await prefs.setBool('is_authenticated', _isAuthenticated);
      await prefs.setBool('has_shared_or_received', _hasSharedOrReceived);
      if (_currentUserId != null) {
        await prefs.setString('current_user_id', _currentUserId!);
      }

    } catch (e) {
      print('❌ Error saving AppState: $e');
    }
  }
}

enum AppFlow {
  splash,
  onboarding,
  main,
}