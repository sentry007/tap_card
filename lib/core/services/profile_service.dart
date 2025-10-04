/// Profile Management Service
///
/// Singleton service that manages user profiles including:
/// - Multiple profile support (Personal, Professional, Custom)
/// - Profile CRUD operations
/// - Active profile switching
/// - Profile data validation
/// - Local storage persistence
///
/// TODO: Firebase - Sync profiles to Firestore
/// TODO: Firebase - Real-time profile updates across devices
library;

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_models.dart';
import '../constants/app_constants.dart';

/// Manages user profiles with local storage and future cloud sync
class ProfileService extends ChangeNotifier {
  // ========== Singleton Pattern ==========
  static final ProfileService _instance = ProfileService._internal();

  /// Get the singleton instance
  factory ProfileService() => _instance;

  ProfileService._internal();

  // ========== Private State ==========

  /// All user profiles (max 3: Personal, Professional, Custom)
  List<ProfileData> _profiles = [];

  /// Profile settings (active profile, order, etc.)
  ProfileSettings _settings = ProfileSettings(activeProfileId: '');

  /// Whether the service has been initialized
  bool _isInitialized = false;

  // ========== Public Getters ==========

  /// Get all profiles
  List<ProfileData> get profiles => _profiles;

  /// Get current settings
  ProfileSettings get settings => _settings;

  /// Whether service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether multiple profiles feature is enabled
  bool get multipleProfilesEnabled => _settings.multipleProfilesEnabled;

  /// Get the currently active profile
  ///
  /// Returns the profile marked as active, or the first profile if none active
  ProfileData? get activeProfile {
    if (_profiles.isEmpty) {
      developer.log(
        '⚠️  No profiles found - User needs to create a profile',
        name: 'ProfileService.Get',
      );
      return null;
    }

    return _profiles.firstWhere(
      (profile) => profile.id == _settings.activeProfileId,
      orElse: () {
        developer.log(
          'ℹ️  Active profile not found, returning first profile',
          name: 'ProfileService.Get',
        );
        return _profiles.first;
      },
    );
  }

  // ========== Initialization ==========

  /// Initialize the profile service
  ///
  /// Loads profiles and settings from storage, creates defaults if needed
  /// TODO: Firebase - Also load profiles from Firestore if authenticated
  Future<void> initialize() async {
    if (_isInitialized) {
      developer.log(
        'ℹ️  ProfileService already initialized, skipping',
        name: 'ProfileService.Init',
      );
      return;
    }

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
      if (_profiles.isEmpty) {
        developer.log(
          '📝 No profiles found - Creating default profiles',
          name: 'ProfileService.Init',
        );
        await _createDefaultProfile();
      }

      // Ensure active profile is valid
      if (_settings.activeProfileId.isEmpty ||
          !_profiles.any((p) => p.id == _settings.activeProfileId)) {
        developer.log(
          '⚠️  Invalid active profile - Setting to first profile',
          name: 'ProfileService.Init',
        );
        await _setActiveProfile(_profiles.first.id);
      }

      _isInitialized = true;

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '✅ ProfileService initialized in ${duration}ms\n'
        '   • Profiles loaded: ${_profiles.length}\n'
        '   • Active profile: ${activeProfile?.name ?? "None"}\n'
        '   • Multiple profiles: $multipleProfilesEnabled',
        name: 'ProfileService.Init',
      );

      // TODO: Firebase - Sync with Firestore
      // if (user is authenticated) {
      //   await _syncWithFirestore();
      // }

      notifyListeners();

    } catch (e, stackTrace) {
      developer.log(
        '❌ Error initializing ProfileService',
        name: 'ProfileService.Init',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ========== Private Storage Methods ==========

  /// Load profiles from SharedPreferences
  ///
  /// TODO: Firebase - Also load from Firestore and merge
  Future<void> _loadProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(StorageKeys.userProfiles);

      if (profilesJson != null) {
        final List<dynamic> profilesList = jsonDecode(profilesJson);
        _profiles = profilesList
            .map((json) => ProfileData.fromJson(json))
            .toList();

        developer.log(
          '📂 Loaded ${_profiles.length} profiles from storage',
          name: 'ProfileService.Load',
        );
      } else {
        developer.log(
          'ℹ️  No profiles found in storage',
          name: 'ProfileService.Load',
        );
      }
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
    final baseTime = now.millisecondsSinceEpoch;

    final personalProfile = ProfileData(
      id: 'personal_$baseTime',
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
      id: 'professional_${baseTime + 1}',
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
      id: 'custom_${baseTime + 2}',
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
    // Update active status
    _profiles = _profiles.map((profile) {
      return profile.copyWith(isActive: profile.id == profileId);
    }).toList();

    _settings = _settings.copyWith(activeProfileId: profileId);

    await _saveProfiles();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setActiveProfile(String profileId) async {
    await _setActiveProfile(profileId);
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
    final index = _profiles.indexWhere((p) => p.id == updatedProfile.id);

    if (index != -1) {
      // Regenerate NFC cache if profile data changed
      final needsCacheUpdate = updatedProfile.needsNfcCacheUpdate;
      final finalProfile = needsCacheUpdate
          ? updatedProfile.regenerateNfcCache()
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

      // TODO: Firebase - Sync to Firestore
      // await _syncProfileToFirestore(finalProfile);
    } else {
      developer.log(
        '⚠️  Profile not found for update: ${updatedProfile.id}',
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

    // TODO: Firebase - Sync deletion to Firestore
    // await _deleteProfileFromFirestore(profileId);
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
}