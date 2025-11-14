/// Local Profile Repository Implementation
///
/// Stores profiles in SharedPreferences (local device storage)
/// Used as fallback when offline or Firebase unavailable
library;

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_models.dart';
import '../constants/app_constants.dart';
import 'profile_repository.dart';

/// Repository implementation using SharedPreferences
class LocalProfileRepository implements ProfileRepository {
  @override
  Future<List<ProfileData>> getAllProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(StorageKeys.userProfiles);

      if (profilesJson != null) {
        final List<dynamic> profilesList = jsonDecode(profilesJson);
        final profiles = profilesList
            .map((json) => ProfileData.fromJson(json))
            .toList();

        developer.log(
          '📂 Loaded ${profiles.length} profiles from local storage',
          name: 'LocalProfileRepo.GetAll',
        );
        return profiles;
      } else {
        developer.log(
          'ℹ️  No profiles found in local storage',
          name: 'LocalProfileRepo.GetAll',
        );
        return [];
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error loading profiles from local storage',
        name: 'LocalProfileRepo.GetAll',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  Future<ProfileData?> getProfileById(String id) async {
    final profiles = await getAllProfiles();
    try {
      return profiles.firstWhere((profile) => profile.id == id);
    } catch (e) {
      developer.log(
        'ℹ️  Profile not found: $id',
        name: 'LocalProfileRepo.GetById',
      );
      return null;
    }
  }

  @override
  Future<ProfileData?> getProfileByType(ProfileType type) async {
    final profiles = await getAllProfiles();
    try {
      return profiles.firstWhere((profile) => profile.type == type);
    } catch (e) {
      developer.log(
        'ℹ️  Profile not found for type: ${type.name}',
        name: 'LocalProfileRepo.GetByType',
      );
      return null;
    }
  }

  @override
  Future<ProfileData> createProfile(ProfileData profile) async {
    final profiles = await getAllProfiles();

    // Add new profile
    profiles.add(profile);

    // Save updated list
    await _saveProfiles(profiles);

    developer.log(
      '✅ Profile created in local storage: ${profile.name}',
      name: 'LocalProfileRepo.Create',
    );

    return profile;
  }

  @override
  Future<ProfileData> updateProfile(ProfileData profile) async {
    final profiles = await getAllProfiles();

    // Find and update profile
    final index = profiles.indexWhere((p) =>
        p.id == profile.id && p.type == profile.type);

    if (index != -1) {
      profiles[index] = profile;
      await _saveProfiles(profiles);

      developer.log(
        '✅ Profile updated in local storage: ${profile.name}',
        name: 'LocalProfileRepo.Update',
      );

      return profile;
    } else {
      developer.log(
        '⚠️  Profile not found for update: ${profile.id}',
        name: 'LocalProfileRepo.Update',
      );
      throw Exception('Profile not found');
    }
  }

  @override
  Future<bool> deleteProfile(String id) async {
    final profiles = await getAllProfiles();
    final initialLength = profiles.length;

    // Remove profile
    profiles.removeWhere((p) => p.id == id);

    if (profiles.length < initialLength) {
      await _saveProfiles(profiles);

      developer.log(
        '✅ Profile deleted from local storage: $id',
        name: 'LocalProfileRepo.Delete',
      );
      return true;
    } else {
      developer.log(
        '⚠️  Profile not found for deletion: $id',
        name: 'LocalProfileRepo.Delete',
      );
      return false;
    }
  }

  @override
  Future<int> batchSyncProfiles(List<ProfileData> profiles) async {
    try {
      await _saveProfiles(profiles);

      developer.log(
        '✅ Batch sync complete: ${profiles.length} profiles saved',
        name: 'LocalProfileRepo.BatchSync',
      );

      return profiles.length;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Batch sync failed',
        name: 'LocalProfileRepo.BatchSync',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  @override
  Future<ProfileSettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(StorageKeys.profileSettings);

      if (settingsJson != null) {
        final settings = ProfileSettings.fromJson(jsonDecode(settingsJson));

        developer.log(
          '⚙️  Loaded profile settings from local storage',
          name: 'LocalProfileRepo.GetSettings',
        );
        return settings;
      } else {
        developer.log(
          'ℹ️  No settings found, using defaults',
          name: 'LocalProfileRepo.GetSettings',
        );
        return ProfileSettings(activeProfileId: '');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error loading settings',
        name: 'LocalProfileRepo.GetSettings',
        error: e,
        stackTrace: stackTrace,
      );
      return ProfileSettings(activeProfileId: '');
    }
  }

  @override
  Future<void> updateSettings(ProfileSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString(StorageKeys.profileSettings, settingsJson);

      developer.log(
        '⚙️  Saved profile settings to local storage',
        name: 'LocalProfileRepo.UpdateSettings',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error saving settings',
        name: 'LocalProfileRepo.UpdateSettings',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to save settings');
    }
  }

  @override
  Future<bool> checkConnection() async {
    // Local storage is always available
    return true;
  }

  @override
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.userProfiles);
      await prefs.remove(StorageKeys.profileSettings);

      developer.log(
        '🗑️  Cleared all profiles from local storage',
        name: 'LocalProfileRepo.ClearAll',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error clearing local storage',
        name: 'LocalProfileRepo.ClearAll',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ========== Private Helper Methods ==========

  /// Save profiles to SharedPreferences
  Future<void> _saveProfiles(List<ProfileData> profiles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = jsonEncode(profiles.map((p) => p.toJson()).toList());
      await prefs.setString(StorageKeys.userProfiles, profilesJson);

      developer.log(
        '💾 Saved ${profiles.length} profiles to local storage',
        name: 'LocalProfileRepo.Save',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error saving profiles',
        name: 'LocalProfileRepo.Save',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to save profiles');
    }
  }
}
