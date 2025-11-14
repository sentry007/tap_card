/// Tests for LocalProfileRepository
///
/// Demonstrates testing repositories with clean architecture
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_card/core/repositories/local_profile_repository.dart';
import 'package:tap_card/core/models/profile_models.dart';

void main() {
  group('LocalProfileRepository', () {
    late LocalProfileRepository repository;

    setUp(() {
      // Initialize SharedPreferences with empty data
      SharedPreferences.setMockInitialValues({});
      repository = LocalProfileRepository();
    });

    test('getAllProfiles returns empty list when no profiles exist', () async {
      // Act
      final profiles = await repository.getAllProfiles();

      // Assert
      expect(profiles, isEmpty);
    });

    test('createProfile adds profile to storage', () async {
      // Arrange
      final profile = ProfileData(
        id: 'test-id',
        type: ProfileType.personal,
        name: 'Test User',
        email: 'test@example.com',
        lastUpdated: DateTime.now(),
      );

      // Act
      await repository.createProfile(profile);
      final profiles = await repository.getAllProfiles();

      // Assert
      expect(profiles.length, 1);
      expect(profiles.first.name, 'Test User');
      expect(profiles.first.email, 'test@example.com');
    });

    test('getProfileById returns correct profile', () async {
      // Arrange
      final profile1 = ProfileData(
        id: 'id-1',
        type: ProfileType.personal,
        name: 'User 1',
        lastUpdated: DateTime.now(),
      );
      final profile2 = ProfileData(
        id: 'id-2',
        type: ProfileType.professional,
        name: 'User 2',
        lastUpdated: DateTime.now(),
      );

      await repository.createProfile(profile1);
      await repository.createProfile(profile2);

      // Act
      final result = await repository.getProfileById('id-2');

      // Assert
      expect(result, isNotNull);
      expect(result!.name, 'User 2');
      expect(result.type, ProfileType.professional);
    });

    test('getProfileById returns null when profile not found', () async {
      // Act
      final result = await repository.getProfileById('non-existent-id');

      // Assert
      expect(result, isNull);
    });

    test('updateProfile modifies existing profile', () async {
      // Arrange
      final profile = ProfileData(
        id: 'test-id',
        type: ProfileType.personal,
        name: 'Original Name',
        lastUpdated: DateTime.now(),
      );

      await repository.createProfile(profile);

      final updatedProfile = profile.copyWith(name: 'Updated Name');

      // Act
      await repository.updateProfile(updatedProfile);
      final result = await repository.getProfileById('test-id');

      // Assert
      expect(result!.name, 'Updated Name');
    });

    test('deleteProfile removes profile from storage', () async {
      // Arrange
      final profile = ProfileData(
        id: 'test-id',
        type: ProfileType.personal,
        name: 'Test User',
        lastUpdated: DateTime.now(),
      );

      await repository.createProfile(profile);

      // Act
      final deleted = await repository.deleteProfile('test-id');
      final profiles = await repository.getAllProfiles();

      // Assert
      expect(deleted, isTrue);
      expect(profiles, isEmpty);
    });

    test('getSettings returns default settings when none exist', () async {
      // Act
      final settings = await repository.getSettings();

      // Assert
      expect(settings.activeProfileId, '');
      expect(settings.multipleProfilesEnabled, false);
    });

    test('updateSettings persists settings', () async {
      // Arrange
      final settings = ProfileSettings(
        activeProfileId: 'test-id',
        multipleProfilesEnabled: true,
        profileOrder: ['id-1', 'id-2'],
      );

      // Act
      await repository.updateSettings(settings);
      final result = await repository.getSettings();

      // Assert
      expect(result.activeProfileId, 'test-id');
      expect(result.multipleProfilesEnabled, true);
      expect(result.profileOrder, ['id-1', 'id-2']);
    });

    test('clearAll removes all profiles and settings', () async {
      // Arrange
      final profile = ProfileData(
        id: 'test-id',
        type: ProfileType.personal,
        name: 'Test User',
        lastUpdated: DateTime.now(),
      );

      await repository.createProfile(profile);
      await repository.updateSettings(
        ProfileSettings(activeProfileId: 'test-id'),
      );

      // Act
      await repository.clearAll();

      // Assert
      final profiles = await repository.getAllProfiles();
      final settings = await repository.getSettings();

      expect(profiles, isEmpty);
      expect(settings.activeProfileId, '');
    });

    test('checkConnection always returns true for local storage', () async {
      // Act
      final isConnected = await repository.checkConnection();

      // Assert
      expect(isConnected, isTrue);
    });

    test('batchSyncProfiles replaces all profiles', () async {
      // Arrange
      final profile1 = ProfileData(
        id: 'id-1',
        type: ProfileType.personal,
        name: 'User 1',
        lastUpdated: DateTime.now(),
      );
      final profile2 = ProfileData(
        id: 'id-2',
        type: ProfileType.professional,
        name: 'User 2',
        lastUpdated: DateTime.now(),
      );

      await repository.createProfile(profile1);

      // Act
      final count = await repository.batchSyncProfiles([profile1, profile2]);

      // Assert
      expect(count, 2);

      final profiles = await repository.getAllProfiles();
      expect(profiles.length, 2);
    });
  });
}
