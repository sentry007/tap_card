/// Profile Management Service
///
/// Manages user profiles including:
/// - Multiple profile support (Personal, Professional, Custom)
/// - Profile CRUD operations
/// - Active profile switching
/// - Profile data validation
/// - Sync with Firebase and local storage
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_models.dart';
import '../constants/app_constants.dart';
import '../repositories/profile_repository.dart';
import '../repositories/local_profile_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/received_cards_repository.dart';
import '../../services/firestore_sync_service.dart';
import '../../services/firebase_config.dart';
import '../../services/validation_service.dart';
import '../../models/history_models.dart';
import '../../utils/logger.dart';
import 'auth_service.dart';

/// Manages user profiles using repository pattern
class ProfileService extends ChangeNotifier {
  // ========== Singleton Pattern (Backward Compatibility) ==========
  static ProfileService? _instance;

  /// Get the singleton instance (deprecated - use DI instead)
  factory ProfileService() {
    _instance ??= ProfileService._(
      profileRepository: null,
      localRepository: null,
      authRepository: null,
    );
    return _instance!;
  }

  // ========== Dependencies (Injected or null for backward compat) ==========
  final ProfileRepository? _profileRepository;
  final LocalProfileRepository? _localRepository;
  final AuthRepository? _authRepository;

  /// Named constructor with dependency injection (new DI way)
  ProfileService.withDependencies({
    required ProfileRepository profileRepository,
    required LocalProfileRepository localRepository,
    required AuthRepository authRepository,
  })  : _profileRepository = profileRepository,
        _localRepository = localRepository,
        _authRepository = authRepository;

  /// Private constructor (old singleton way - backward compat)
  ProfileService._({
    required ProfileRepository? profileRepository,
    required LocalProfileRepository? localRepository,
    required AuthRepository? authRepository,
  })  : _profileRepository = profileRepository,
        _localRepository = localRepository,
        _authRepository = authRepository;

  // ========== Private State ==========

  /// All user profiles (max 3: Personal, Professional, Custom)
  List<ProfileData> _profiles = [];

  /// Profile settings (active profile, order, etc.)
  ProfileSettings _settings = ProfileSettings(activeProfileId: '');

  /// Whether the service has been initialized
  bool _isInitialized = false;

  /// Whether profiles have been loaded from storage
  /// This flag prevents race conditions in router redirect logic
  bool _isLoaded = false;

  /// Initialization lock to prevent concurrent initialization calls
  static bool _initInProgress = false;
  static Future<void>? _initFuture;

  // ========== Public Getters ==========

  /// Get all profiles
  List<ProfileData> get profiles => _profiles;

  /// Get current settings
  ProfileSettings get settings => _settings;

  /// Whether service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether profiles have finished loading
  ///
  /// Use this to check if profiles are ready before making navigation decisions
  /// Prevents race conditions where router checks profiles before they load
  bool get isLoaded => _isLoaded;

  /// Whether multiple profiles feature is enabled
  bool get multipleProfilesEnabled => _settings.multipleProfilesEnabled;

  /// Get the currently active profile
  ///
  /// Returns the profile marked as active by the isActive flag
  /// For shared UUID architecture, the isActive flag indicates which TYPE is active
  ProfileData? get activeProfile {
    if (_profiles.isEmpty) {
      developer.log(
        '⚠️  No profiles found - User needs to create a profile',
        name: 'ProfileService.Get',
      );
      return null;
    }

    // First try to find a profile marked as active
    try {
      return _profiles.firstWhere((profile) => profile.isActive);
    } catch (e) {
      // If no profile is marked active, fall back to ID-based lookup
      developer.log(
        'ℹ️  No active profile found by flag, using ID fallback',
        name: 'ProfileService.Get',
      );

      try {
        return _profiles.firstWhere(
          (profile) => profile.id == _settings.activeProfileId,
        );
      } catch (e) {
        developer.log(
          '⚠️  Active profile not found, returning first profile',
          name: 'ProfileService.Get',
        );
        return _profiles.first;
      }
    }
  }

  // ========== Initialization ==========

  /// Initialize the profile service
  ///
  /// Loads profiles and settings from storage, creates defaults if needed
  /// TODO: Firebase - Also load profiles from Firestore if authenticated
  Future<void> initialize() async {
    // Already initialized - skip
    if (_isInitialized) {
      developer.log(
        'ℹ️  ProfileService already initialized, skipping',
        name: 'ProfileService.Init',
      );
      return;
    }

    // Initialization already in progress - wait for it to complete
    if (_initInProgress && _initFuture != null) {
      developer.log(
        'ℹ️  Initialization already in progress, waiting...',
        name: 'ProfileService.Init',
      );
      await _initFuture;
      return;
    }

    // Start initialization
    _initInProgress = true;
    final completer = Completer<void>();
    _initFuture = completer.future;

    final startTime = DateTime.now();

    try {
      developer.log(
        '🔧 Initializing ProfileService...',
        name: 'ProfileService.Init',
      );

      // Load data from storage
      await Future.wait([
        _loadProfiles(),
        _loadSettings(),
      ]);

      // Create default profiles if none exist (3 profiles: one per type)
      // Only create if user is authenticated - otherwise wait for auth
      if (_profiles.isEmpty) {
        final authService = AuthService();
        if (authService.uid != null) {
          developer.log(
            '📝 No profiles found - Creating default profiles',
            name: 'ProfileService.Init',
          );
          await _createDefaultProfile();
        } else {
          developer.log(
            'ℹ️  No profiles found and no UID available yet\n'
            '   Profiles will be created after user authenticates',
            name: 'ProfileService.Init',
          );
        }
      }

      // Ensure active profile is valid (only if we have profiles)
      if (_profiles.isNotEmpty) {
        if (_settings.activeProfileId.isEmpty ||
            !_profiles.any((p) => p.id == _settings.activeProfileId)) {
          developer.log(
            '⚠️  Invalid active profile - Setting to first profile',
            name: 'ProfileService.Init',
          );
          await _setActiveProfile(_profiles.first.id);
        }
      }

      _isInitialized = true;
      _isLoaded = true; // Mark profiles as loaded after initialization

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '✅ ProfileService initialized in ${duration}ms\n'
        '   • Profiles loaded: ${_profiles.length}\n'
        '   • Active profile: ${activeProfile?.name ?? "None"}\n'
        '   • Multiple profiles: $multipleProfilesEnabled\n'
        '   • Profiles ready: $_isLoaded',
        name: 'ProfileService.Init',
      );

      // TODO: Firebase - Sync with Firestore
      // if (user is authenticated) {
      //   await _syncWithFirestore();
      // }

      notifyListeners();

      // Complete the initialization future successfully
      completer.complete();

    } catch (e, stackTrace) {
      developer.log(
        '❌ Error initializing ProfileService',
        name: 'ProfileService.Init',
        error: e,
        stackTrace: stackTrace,
      );

      // Complete with error so waiting callers can handle it
      completer.completeError(e, stackTrace);
      rethrow;
    } finally {
      // Reset initialization state
      _initInProgress = false;
      _initFuture = null;
    }
  }

  // ========== Private Storage Methods ==========

  /// Load profiles from repository
  ///
  /// Uses local repository if injected, otherwise falls back to SharedPreferences
  Future<void> _loadProfiles() async {
    try {
      // New way: Use injected repository
      if (_localRepository != null) {
        _profiles = await _localRepository!.getAllProfiles();
      } else {
        // Old way: Direct SharedPreferences access
        final prefs = await SharedPreferences.getInstance();
        final profilesJson = prefs.getString(StorageKeys.userProfiles);

        if (profilesJson != null) {
          final List<dynamic> profilesList = jsonDecode(profilesJson);
          _profiles = profilesList
              .map((json) => ProfileData.fromJson(json))
              .toList();
        }
      }

      developer.log(
        '📂 Loaded ${_profiles.length} profiles from storage',
        name: 'ProfileService.Load',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error loading profiles from storage',
        name: 'ProfileService.Load',
        error: e,
        stackTrace: stackTrace,
      );
      _profiles = [];
    }
  }

  /// Load settings from SharedPreferences
  ///
  /// TODO: Firebase - Also load from Firestore
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(StorageKeys.profileSettings);

      if (settingsJson != null) {
        _settings = ProfileSettings.fromJson(jsonDecode(settingsJson));

        developer.log(
          '⚙️  Loaded profile settings from storage',
          name: 'ProfileService.Load',
        );
      } else {
        developer.log(
          'ℹ️  No settings found in storage, using defaults',
          name: 'ProfileService.Load',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error loading settings from storage',
        name: 'ProfileService.Load',
        error: e,
        stackTrace: stackTrace,
      );
      _settings = ProfileSettings(activeProfileId: '');
    }
  }

  /// Save profiles to SharedPreferences
  ///
  /// TODO: Firebase - Also sync to Firestore
  Future<void> _saveProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = jsonEncode(_profiles.map((p) => p.toJson()).toList());
      await prefs.setString(StorageKeys.userProfiles, profilesJson);

      developer.log(
        '💾 Saved ${_profiles.length} profiles to storage',
        name: 'ProfileService.Save',
      );

      // TODO: Firebase - Sync to Firestore
      // await _syncProfilesToFirestore();

    } catch (e, stackTrace) {
      developer.log(
        '❌ Error saving profiles to storage',
        name: 'ProfileService.Save',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Save settings to SharedPreferences
  ///
  /// TODO: Firebase - Also sync to Firestore
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_settings.toJson());
      await prefs.setString(StorageKeys.profileSettings, settingsJson);

      developer.log(
        '⚙️  Saved profile settings to storage',
        name: 'ProfileService.Save',
      );

      // TODO: Firebase - Sync to Firestore
      // await _syncSettingsToFirestore();

    } catch (e, stackTrace) {
      developer.log(
        '❌ Error saving settings to storage',
        name: 'ProfileService.Save',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _createDefaultProfile() async {
    // Create exactly 3 profiles - one for each type with realistic mock data
    final now = DateTime.now();

    // Use Firebase Auth UID as the ONLY profile ID - all profiles share the same user ID
    final authService = AuthService();
    final userUuid = authService.uid;

    if (userUuid == null) {
      developer.log(
        '❌ Cannot create profile - No Firebase Auth UID available\n'
        '   User must be authenticated first',
        name: 'ProfileService.CreateDefault',
      );
      throw Exception('User must be authenticated to create profile');
    }

    developer.log(
      '🆔 Using Firebase Auth UID for all profiles: $userUuid\n'
      '   All 3 profile types will share this same ID',
      name: 'ProfileService.CreateDefault',
    );

    final personalProfile = ProfileData(
      id: userUuid,  // Same UUID for all profiles
      type: ProfileType.personal,
      name: 'Alex Rivera',
      phone: '+1 (555) 123-4567',
      email: 'alex.rivera@gmail.com',
      socialMedia: {
        'instagram': '@alexrivera_',
        'snapchat': 'alex.rivera.snaps',
        'tiktok': '@alexrivera'
      },
      lastUpdated: now,
      isActive: true,
    );

    final professionalProfile = ProfileData(
      id: userUuid,  // Same UUID for all profiles
      type: ProfileType.professional,
      name: 'Alex Rivera',
      phone: '+1 (555) 987-6543',
      company: 'TechFlow Solutions',
      title: 'Senior Product Designer',
      email: 'alex@techflow.com',
      website: 'alexrivera.design',
      socialMedia: {
        'linkedin': '/in/alexrivera-design'
      },
      lastUpdated: now,
      isActive: false,
    );

    final customProfile = ProfileData(
      id: userUuid,  // Same UUID for all profiles
      type: ProfileType.custom,
      name: 'Alex Rivera',
      phone: '+1 (555) 456-7890',
      title: 'Content Creator',
      email: 'hello@alexcreates.co',
      website: 'alexcreates.co',
      socialMedia: {
        'youtube': '@AlexCreates',
        'instagram': '@alex_creates'
      },
      lastUpdated: now,
      isActive: false,
    );

    _profiles = [personalProfile, professionalProfile, customProfile];
    _settings = ProfileSettings(
      activeProfileId: personalProfile.id,
      profileOrder: [personalProfile.id, professionalProfile.id, customProfile.id],
    );

    await _saveProfiles();
    await _saveSettings();
  }

  // ========== Profile-Auth Synchronization ==========

  /// Ensure profiles exist and match current Firebase UID
  ///
  /// Call this after any authentication event (guest, Google, phone)
  /// Handles profile creation and UID migration
  Future<void> ensureProfilesExist() async {
    Logger.info('ensureProfilesExist() called', name: 'PROFILE');

    try {
      final authService = AuthService();
      final currentUid = authService.uid;

      Logger.debug('Current UID from AuthService: ${currentUid ?? "null"}\n  Existing profiles count: ${_profiles.length}\n  isLoaded before: $_isLoaded', name: 'PROFILE');

      if (currentUid == null) {
        Logger.warning('No Firebase UID available - cannot ensure profiles', name: 'PROFILE');
        // Still mark as loaded to prevent infinite waiting
        _isLoaded = true;
        notifyListeners();
        return;
      }

      if (_profiles.isEmpty) {
        // No profiles at all - create them with current UID
        Logger.info('No profiles found - creating default profiles with UID: $currentUid', name: 'PROFILE');
        await _createDefaultProfile();
        Logger.info('Default profiles created successfully', name: 'PROFILE');
      } else if (_profiles.first.id != currentUid) {
        // UID mismatch - profiles were created with different UID
        // This happens when user had anonymous account and upgraded to Google
        Logger.warning('UID mismatch detected!\n  Old UID: ${_profiles.first.id}\n  New UID: $currentUid', name: 'PROFILE');
        Logger.info('Migrating profiles to new UID...', name: 'PROFILE');
        await _migrateProfilesToNewUid(currentUid);
        Logger.info('Profile migration complete', name: 'PROFILE');
      } else {
        Logger.info('Profiles already exist and match current UID', name: 'PROFILE');
      }

      _isLoaded = true; // Mark profiles as loaded after ensuring they exist
      Logger.debug('isLoaded set to: $_isLoaded', name: 'PROFILE');
      notifyListeners();
      Logger.info('ensureProfilesExist() complete - notified listeners', name: 'PROFILE');

    } catch (e, stackTrace) {
      Logger.error(
        'CRITICAL: ensureProfilesExist() failed: $e',
        name: 'PROFILE',
        error: e,
        stackTrace: stackTrace,
      );

      // IMPORTANT: Still mark as loaded to prevent app from getting stuck
      // App can recover by recreating profiles on next auth event
      _isLoaded = true;
      notifyListeners();

      // Don't rethrow - log and continue to keep app functional
      // User will be prompted to recreate profiles if needed
    }
  }

  /// Migrate all profiles to a new UID
  ///
  /// Used when upgrading from anonymous to real account
  Future<void> _migrateProfilesToNewUid(String newUid) async {
    developer.log(
      '🔄 Migrating ${_profiles.length} profiles to new UID: $newUid',
      name: 'ProfileService.Migration',
    );

    // Update all profile UIDs
    _profiles = _profiles.map((p) => p.copyWith(id: newUid)).toList();

    // Update settings with new UID
    _settings = _settings.copyWith(activeProfileId: newUid);

    await _saveProfiles();
    await _saveSettings();

    developer.log(
      '✅ Profile migration complete - all profiles now use UID: $newUid',
      name: 'ProfileService.Migration',
    );
  }

  /// Clear all profiles from storage
  ///
  /// Called when user signs out completely
  Future<void> clearAllProfiles() async {
    developer.log(
      '🗑️  Clearing all profiles...',
      name: 'ProfileService.Clear',
    );

    _profiles = [];
    _settings = ProfileSettings(activeProfileId: '');
    _isLoaded = false; // Reset loaded flag on sign-out

    await _saveProfiles();
    await _saveSettings();

    developer.log(
      '✅ All profiles cleared - profiles no longer loaded',
      name: 'ProfileService.Clear',
    );

    notifyListeners();
  }

  Future<void> enableMultipleProfiles() async {
    // Ensure we have exactly 3 profiles when enabling multiple profiles
    if (_profiles.length != 3) {
      await _createDefaultProfile();
    } else {
      // If we already have profiles, ensure we have one for each type
      final hasPersonal = _profiles.any((p) => p.type == ProfileType.personal);
      final hasProfessional = _profiles.any((p) => p.type == ProfileType.professional);
      final hasCustom = _profiles.any((p) => p.type == ProfileType.custom);

      if (!hasPersonal || !hasProfessional || !hasCustom) {
        await _createDefaultProfile();
      }
    }

    _settings = _settings.copyWith(multipleProfilesEnabled: true);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> disableMultipleProfiles() async {
    // When disabling, keep only the active profile
    if (activeProfile != null) {
      _profiles = [activeProfile!.copyWith(isActive: true)];
      _settings = _settings.copyWith(
        multipleProfilesEnabled: false,
        profileOrder: [activeProfile!.id],
      );
      await _saveProfiles();
      await _saveSettings();
    }
    notifyListeners();
  }

  Future<void> _setActiveProfile(String profileId) async {
    // Find the target profile by ID (there may be multiple with same ID but different types)
    // When called from _switchToProfileType, we need to identify which TYPE to activate
    final targetProfile = _profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => _profiles.first,
    );

    // Update active status - when profiles share same ID, we need to track the active TYPE
    // Mark only the specific profile (by ID + TYPE combo) as active
    _profiles = _profiles.map((profile) {
      // If this is the exact profile we want (matching both ID and type from activeProfile getter)
      // OR if we're setting initial profile, mark it active
      final shouldBeActive = profile.id == profileId &&
        (profile.type == targetProfile.type || profile.isActive);
      return profile.copyWith(isActive: shouldBeActive);
    }).toList();

    _settings = _settings.copyWith(activeProfileId: profileId);

    await _saveProfiles();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setActiveProfile(String profileId) async {
    await _setActiveProfile(profileId);
  }

  /// Set active profile by type (for shared UUID architecture)
  /// This is used when switching between profile types that share the same UUID
  Future<void> setActiveProfileByType(ProfileType type) async {
    final profile = getProfileByType(type);
    if (profile == null) return;

    // Mark only this type as active, others as inactive
    _profiles = _profiles.map((p) {
      return p.copyWith(isActive: p.type == type);
    }).toList();

    // Keep the same profile ID in settings (shared UUID)
    _settings = _settings.copyWith(activeProfileId: profile.id);

    await _saveProfiles();
    await _saveSettings();
    notifyListeners();

    developer.log(
      '🔄 Switched active profile to ${type.label}\n'
      '   • Profile name: ${profile.name}',
      name: 'ProfileService.Switch',
    );
  }

  // No longer needed - we always have exactly 3 profiles
  @Deprecated('Profiles are now fixed - use getProfileByType instead')
  Future<void> createProfile(ProfileType type) async {
    // This method is no longer used since we have fixed 3 profiles
    return;
  }

  // ========== Profile CRUD Operations ==========

  /// Update an existing profile
  ///
  /// Updates profile data and regenerates NFC cache if needed
  /// TODO: Firebase - Sync changes to Firestore
  Future<void> updateProfile(ProfileData updatedProfile) async {
    // When profiles share the same ID, match by both ID and TYPE
    final index = _profiles.indexWhere((p) =>
      p.id == updatedProfile.id && p.type == updatedProfile.type);

    if (index != -1) {
      // ✅ Validate profile (warning mode - doesn't block)
      final validation = ValidationService.validateProfile(updatedProfile);
      if (!validation.isValid) {
        developer.log(
          '⚠️ Profile validation warnings:\n'
          '   Profile: ${updatedProfile.name}\n'
          '   Issues: ${validation.userMessage}\n'
          '   ℹ️ Continuing anyway (warning mode active)',
          name: 'ProfileService.Update',
        );
        // Don't throw - just log the warning
        // In Phase 2, we'll enforce validation here
      }

      // Regenerate NFC cache if profile data changed (includes dual-payload)
      final needsCacheUpdate = updatedProfile.needsNfcCacheUpdate;
      final finalProfile = needsCacheUpdate
          ? updatedProfile.regenerateDualPayloadCache()
          : updatedProfile.copyWith(lastUpdated: DateTime.now());

      _profiles[index] = finalProfile;

      developer.log(
        '✏️  Updated profile: ${finalProfile.name} (${finalProfile.type.name})\n'
        '   • NFC cache regenerated: $needsCacheUpdate\n'
        '   • Profile is NFC ready: ${finalProfile.isNfcReady}',
        name: 'ProfileService.Update',
      );

      await _saveProfiles();
      notifyListeners();

      // Sync to Firestore (non-blocking background operation)
      if (FirebaseConfig.useFirestoreForProfiles) {
        _syncProfileToFirestore(finalProfile);
      }
    } else {
      developer.log(
        '⚠️  Profile not found for update: ${updatedProfile.id} (${updatedProfile.type.name})',
        name: 'ProfileService.Update',
      );
    }
  }

  /// Delete a profile
  ///
  /// Cannot delete the last profile. If deleting active profile, switches to another
  /// TODO: Firebase - Sync deletion to Firestore
  Future<void> deleteProfile(String profileId) async {
    if (_profiles.length <= 1) {
      developer.log(
        '⚠️  Cannot delete last profile',
        name: 'ProfileService.Delete',
      );
      return;
    }

    final deletedProfile = _profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => _profiles.first,
    );

    _profiles.removeWhere((p) => p.id == profileId);

    // Update profile order
    final newOrder = _settings.profileOrder
        .where((id) => id != profileId)
        .toList();

    // If we deleted the active profile, set a new active profile
    String newActiveId = _settings.activeProfileId;
    if (_settings.activeProfileId == profileId) {
      newActiveId = _profiles.first.id;
      await _setActiveProfile(newActiveId);
    }

    _settings = _settings.copyWith(
      activeProfileId: newActiveId,
      profileOrder: newOrder,
    );

    developer.log(
      '🗑️  Deleted profile: ${deletedProfile.name}\n'
      '   • New active profile: ${activeProfile?.name}\n'
      '   • Remaining profiles: ${_profiles.length}',
      name: 'ProfileService.Delete',
    );

    await _saveProfiles();
    await _saveSettings();
    notifyListeners();

    // Sync deletion to Firestore (non-blocking)
    if (FirebaseConfig.useFirestoreForProfiles) {
      _deleteProfileFromFirestore(profileId);
    }
  }

  /// Reorder profiles in the UI
  ///
  /// Updates the display order of profiles
  Future<void> reorderProfiles(List<String> newOrder) async {
    _settings = _settings.copyWith(profileOrder: newOrder);

    developer.log(
      '🔄 Profiles reordered: ${newOrder.join(", ")}',
      name: 'ProfileService.Reorder',
    );

    await _saveSettings();
    notifyListeners();
  }

  // ========== Profile Query Methods ==========

  /// Get a specific profile by ID
  ///
  /// Returns null if profile not found
  ProfileData? getProfile(String id) {
    try {
      return _profiles.firstWhere((profile) => profile.id == id);
    } catch (e) {
      developer.log(
        'ℹ️  Profile not found: $id',
        name: 'ProfileService.Get',
      );
      return null;
    }
  }

  /// Get all profiles of a specific type
  ///
  /// Useful for filtering profiles by Personal/Professional/Custom
  List<ProfileData> getProfilesByType(ProfileType type) {
    return _profiles.where((profile) => profile.type == type).toList();
  }

  int getProfileCount() => _profiles.length;

  bool canAddMoreProfiles() {
    // Always return false since we have fixed 3 profiles
    return false;
  }

  ProfileData? getProfileByType(ProfileType type) {
    try {
      return _profiles.firstWhere((profile) => profile.type == type);
    } catch (e) {
      return null;
    }
  }

  /// Add received card to active profile and ReceivedCardsRepository
  ///
  /// **Two-layer tracking:**
  /// 1. ProfileData.receivedCardUuids - User's personal list
  /// 2. ReceivedCardsRepository - App-wide persistent storage
  ///
  /// Prevents duplicates - only adds if UUID not already in list
  Future<void> addReceivedCard(
    String receivedProfileUuid, {
    required ProfileData receivedProfile,
    required ShareMethod shareMethod,
  }) async {
    final active = activeProfile;
    if (active == null) {
      developer.log(
        '⚠️ No active profile - cannot add received card',
        name: 'ProfileService.ReceivedCards',
      );
      return;
    }

    // Don't add duplicates to ProfileData list
    final alreadyInProfile = active.receivedCardUuids.contains(receivedProfileUuid);

    if (!alreadyInProfile) {
      // Add to active profile's list
      final updatedUuids = [...active.receivedCardUuids, receivedProfileUuid];
      final updatedProfile = active.copyWith(receivedCardUuids: updatedUuids);

      developer.log(
        '📇 Added received card to active profile\n'
        '   • Received UUID: $receivedProfileUuid\n'
        '   • Profile: ${receivedProfile.name}\n'
        '   • Total received: ${updatedUuids.length}',
        name: 'ProfileService.ReceivedCards',
      );

      await updateProfile(updatedProfile);
    } else {
      developer.log(
        'ℹ️ Card already in profile list: $receivedProfileUuid',
        name: 'ProfileService.ReceivedCards',
      );
    }

    // ✅ ALWAYS sync to ReceivedCardsRepository (handles duplicates internally)
    // This ensures repository stays in sync even if profile list already had it
    final repository = ReceivedCardsRepository();
    await repository.addReceivedCard(
      receivedProfileUuid,
      profile: receivedProfile,
      shareMethod: shareMethod,
    );
  }

  // ========== Firebase Sync Methods ==========

  /// Sync profile to Firestore (background, non-blocking)
  ///
  /// Uploads profile data to Firebase Firestore
  /// Updates local profile with Firebase URLs after successful upload
  /// Errors are logged but don't block the user
  void _syncProfileToFirestore(ProfileData profile) {
    FirestoreSyncService.syncProfileToFirestore(profile).then((urls) {
      if (urls != null) {
        // Update local profile with Firebase URLs
        final index = _profiles.indexWhere((p) => p.id == profile.id);
        if (index != -1) {
          var updatedProfile = _profiles[index];
          bool needsUpdate = false;

          // Update profile image URL if uploaded
          if (urls['profileImageUrl'] != null &&
              urls['profileImageUrl']!.isNotEmpty &&
              urls['profileImageUrl'] != updatedProfile.profileImagePath) {
            updatedProfile = updatedProfile.copyWith(
              profileImagePath: urls['profileImageUrl'],
            );
            needsUpdate = true;
            developer.log(
              '📸 Profile image URL updated to Firebase URL',
              name: 'ProfileService.Sync',
            );
          }

          // Update background image URL if uploaded
          if (urls['backgroundImageUrl'] != null &&
              urls['backgroundImageUrl']!.isNotEmpty &&
              urls['backgroundImageUrl'] != updatedProfile.cardAesthetics.backgroundImagePath) {
            final updatedAesthetics = updatedProfile.cardAesthetics.copyWith(
              backgroundImagePath: urls['backgroundImageUrl'],
            );
            updatedProfile = updatedProfile.copyWith(
              cardAesthetics: updatedAesthetics,
            );
            needsUpdate = true;
            developer.log(
              '🖼️ Background image URL updated to Firebase URL',
              name: 'ProfileService.Sync',
            );
          }

          // Save updated profile with Firebase URLs
          if (needsUpdate) {
            _profiles[index] = updatedProfile;
            _saveProfiles();
            notifyListeners();
          }
        }

        developer.log(
          '✅ Background sync complete for ${profile.name}',
          name: 'ProfileService.Sync',
        );
      } else {
        developer.log(
          '⚠️ Background sync failed for ${profile.name} - Profile saved locally',
          name: 'ProfileService.Sync',
        );
      }
    }).catchError((error, stackTrace) {
      developer.log(
        '❌ Background sync error for ${profile.name} - Profile saved locally',
        name: 'ProfileService.Sync',
        error: error,
        stackTrace: stackTrace,
      );
    });
  }

  /// Delete profile from Firestore (background, non-blocking)
  ///
  /// Removes profile from Firebase Firestore and Storage
  /// Errors are logged but don't block the user
  void _deleteProfileFromFirestore(String profileId) {
    FirestoreSyncService.deleteProfileFromFirestore(profileId).then((success) {
      if (success) {
        developer.log(
          '✅ Background deletion complete for profile $profileId',
          name: 'ProfileService.Sync',
        );
      } else {
        developer.log(
          '⚠️ Background deletion failed for $profileId',
          name: 'ProfileService.Sync',
        );
      }
    }).catchError((error, stackTrace) {
      developer.log(
        '❌ Background deletion error for $profileId',
        name: 'ProfileService.Sync',
        error: error,
        stackTrace: stackTrace,
      );
    });
  }

  /// Batch sync all profiles to Firestore
  ///
  /// Useful for initial migration or recovery
  /// Returns number of successfully synced profiles
  Future<int> syncAllProfilesToFirestore() async {
    if (!FirebaseConfig.useFirestoreForProfiles) {
      developer.log(
        '⚠️ Firestore sync disabled in config',
        name: 'ProfileService.BatchSync',
      );
      return 0;
    }

    developer.log(
      '📦 Starting batch sync of ${_profiles.length} profiles...',
      name: 'ProfileService.BatchSync',
    );

    final count = await FirestoreSyncService.batchSyncProfiles(_profiles);

    developer.log(
      '✅ Batch sync complete: $count/${_profiles.length} profiles synced',
      name: 'ProfileService.BatchSync',
    );

    return count;
  }
}