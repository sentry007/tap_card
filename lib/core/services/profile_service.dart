import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_models.dart';

class ProfileService extends ChangeNotifier {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  static const String _profilesKey = 'user_profiles';
  static const String _settingsKey = 'profile_settings';

  List<ProfileData> _profiles = [];
  ProfileSettings _settings = ProfileSettings(activeProfileId: '');
  bool _isInitialized = false;

  List<ProfileData> get profiles => _profiles;
  ProfileSettings get settings => _settings;
  bool get isInitialized => _isInitialized;
  bool get multipleProfilesEnabled => _settings.multipleProfilesEnabled;

  ProfileData? get activeProfile {
    if (_profiles.isEmpty) return null;
    return _profiles.firstWhere(
      (profile) => profile.id == _settings.activeProfileId,
      orElse: () => _profiles.first,
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadProfiles();
      await _loadSettings();

      // Create default profile if none exist
      if (_profiles.isEmpty) {
        await _createDefaultProfile();
      }

      // Ensure active profile is set
      if (_settings.activeProfileId.isEmpty ||
          !_profiles.any((p) => p.id == _settings.activeProfileId)) {
        await _setActiveProfile(_profiles.first.id);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing ProfileService: $e');
    }
  }

  Future<void> _loadProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_profilesKey);

      if (profilesJson != null) {
        final List<dynamic> profilesList = jsonDecode(profilesJson);
        _profiles = profilesList.map((json) => ProfileData.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading profiles: $e');
      _profiles = [];
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        _settings = ProfileSettings.fromJson(jsonDecode(settingsJson));
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _settings = ProfileSettings(activeProfileId: '');
    }
  }

  Future<void> _saveProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = jsonEncode(_profiles.map((p) => p.toJson()).toList());
      await prefs.setString(_profilesKey, profilesJson);
    } catch (e) {
      debugPrint('Error saving profiles: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
    } catch (e) {
      debugPrint('Error saving settings: $e');
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

  Future<void> updateProfile(ProfileData updatedProfile) async {
    final index = _profiles.indexWhere((p) => p.id == updatedProfile.id);
    if (index != -1) {
      _profiles[index] = updatedProfile.copyWith(lastUpdated: DateTime.now());
      await _saveProfiles();
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String profileId) async {
    if (_profiles.length <= 1) return; // Can't delete last profile

    _profiles.removeWhere((p) => p.id == profileId);

    // Update profile order
    final newOrder = _settings.profileOrder.where((id) => id != profileId).toList();

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

    await _saveProfiles();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> reorderProfiles(List<String> newOrder) async {
    _settings = _settings.copyWith(profileOrder: newOrder);
    await _saveSettings();
    notifyListeners();
  }

  ProfileData? getProfile(String id) {
    try {
      return _profiles.firstWhere((profile) => profile.id == id);
    } catch (e) {
      return null;
    }
  }

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