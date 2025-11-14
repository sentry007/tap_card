/// Profile Repository Interface
///
/// Abstract repository defining all profile data operations.
/// Implementations handle where data is stored (Firebase, local, etc.)
///
/// Benefits:
/// - Swap data sources without changing business logic
/// - Easy to mock for testing
/// - Single responsibility (data access only)
library;

import '../models/profile_models.dart';

/// Abstract repository for profile data operations
///
/// Implementations:
/// - FirebaseProfileRepository: Firestore + Storage
/// - LocalProfileRepository: SharedPreferences
abstract class ProfileRepository {
  // ========== CRUD Operations ==========

  /// Get all profiles for the current user
  Future<List<ProfileData>> getAllProfiles();

  /// Get a specific profile by ID
  Future<ProfileData?> getProfileById(String id);

  /// Get profile by type (Personal, Professional, Custom)
  Future<ProfileData?> getProfileByType(ProfileType type);

  /// Create a new profile
  /// Returns the created profile with updated metadata
  Future<ProfileData> createProfile(ProfileData profile);

  /// Update an existing profile
  /// Returns the updated profile
  Future<ProfileData> updateProfile(ProfileData profile);

  /// Delete a profile by ID
  /// Returns true if successful
  Future<bool> deleteProfile(String id);

  /// Batch sync multiple profiles
  /// Returns number of successfully synced profiles
  Future<int> batchSyncProfiles(List<ProfileData> profiles);

  // ========== Settings Operations ==========

  /// Get profile settings (active profile, order, etc.)
  Future<ProfileSettings> getSettings();

  /// Update profile settings
  Future<void> updateSettings(ProfileSettings settings);

  // ========== Utility Operations ==========

  /// Check if repository is accessible (network, permissions, etc.)
  Future<bool> checkConnection();

  /// Clear all data (for sign-out)
  Future<void> clearAll();
}
