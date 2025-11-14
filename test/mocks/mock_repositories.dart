/// Mock Repositories for Testing
///
/// Provides mock implementations of repositories for unit testing
library;

import 'package:tap_card/core/models/profile_models.dart';
import 'package:tap_card/core/repositories/profile_repository.dart';
import 'package:tap_card/core/repositories/auth_repository.dart';
import 'package:tap_card/core/repositories/storage_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Mock Profile Repository
///
/// In-memory repository for testing
class MockProfileRepository implements ProfileRepository {
  final List<ProfileData> _profiles = [];
  ProfileSettings _settings = ProfileSettings(activeProfileId: '');
  bool _shouldFail = false;

  /// Set whether operations should fail (for testing error handling)
  void setShouldFail(bool value) {
    _shouldFail = value;
  }

  @override
  Future<List<ProfileData>> getAllProfiles() async {
    if (_shouldFail) throw Exception('Mock failure');
    return List.from(_profiles);
  }

  @override
  Future<ProfileData?> getProfileById(String id) async {
    if (_shouldFail) throw Exception('Mock failure');
    try {
      return _profiles.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ProfileData?> getProfileByType(ProfileType type) async {
    if (_shouldFail) throw Exception('Mock failure');
    try {
      return _profiles.firstWhere((p) => p.type == type);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ProfileData> createProfile(ProfileData profile) async {
    if (_shouldFail) throw Exception('Mock failure');
    _profiles.add(profile);
    return profile;
  }

  @override
  Future<ProfileData> updateProfile(ProfileData profile) async {
    if (_shouldFail) throw Exception('Mock failure');
    final index = _profiles.indexWhere((p) =>
        p.id == profile.id && p.type == profile.type);
    if (index != -1) {
      _profiles[index] = profile;
      return profile;
    }
    throw Exception('Profile not found');
  }

  @override
  Future<bool> deleteProfile(String id) async {
    if (_shouldFail) throw Exception('Mock failure');
    final initialLength = _profiles.length;
    _profiles.removeWhere((p) => p.id == id);
    return _profiles.length < initialLength;
  }

  @override
  Future<int> batchSyncProfiles(List<ProfileData> profiles) async {
    if (_shouldFail) throw Exception('Mock failure');
    _profiles.clear();
    _profiles.addAll(profiles);
    return profiles.length;
  }

  @override
  Future<ProfileSettings> getSettings() async {
    if (_shouldFail) throw Exception('Mock failure');
    return _settings;
  }

  @override
  Future<void> updateSettings(ProfileSettings settings) async {
    if (_shouldFail) throw Exception('Mock failure');
    _settings = settings;
  }

  @override
  Future<bool> checkConnection() async {
    if (_shouldFail) return false;
    return true;
  }

  @override
  Future<void> clearAll() async {
    if (_shouldFail) throw Exception('Mock failure');
    _profiles.clear();
    _settings = ProfileSettings(activeProfileId: '');
  }
}

/// Mock Auth Repository
///
/// Simulates Firebase Auth for testing
class MockAuthRepository implements AuthRepository {
  User? _currentUser;
  bool _shouldFail = false;

  /// Set whether operations should fail (for testing error handling)
  void setShouldFail(bool value) {
    _shouldFail = value;
  }

  /// Set mock user
  void setMockUser(User? user) {
    _currentUser = user;
  }

  @override
  User? get currentUser => _currentUser;

  @override
  String? get uid => _currentUser?.uid;

  @override
  bool get isSignedIn => _currentUser != null;

  @override
  bool get isAnonymous => _currentUser?.isAnonymous ?? false;

  @override
  Stream<User?> get authStateChanges => Stream.value(_currentUser);

  @override
  Future<UserCredential> signInAnonymously() async {
    if (_shouldFail) throw Exception('Mock failure');
    // Return mock UserCredential
    throw UnimplementedError('Use a proper mocking library for UserCredential');
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    if (_shouldFail) throw Exception('Mock failure');
    throw UnimplementedError('Use a proper mocking library for UserCredential');
  }

  @override
  Future<void> signOut() async {
    if (_shouldFail) throw Exception('Mock failure');
    _currentUser = null;
  }

  @override
  Future<void> deleteAccount() async {
    if (_shouldFail) throw Exception('Mock failure');
    _currentUser = null;
  }

  @override
  Future<UserCredential> linkWithGoogle() async {
    if (_shouldFail) throw Exception('Mock failure');
    throw UnimplementedError('Use a proper mocking library for UserCredential');
  }
}

/// Mock Storage Repository
///
/// Simulates Firebase Storage for testing
class MockStorageRepository implements StorageRepository {
  final Map<String, String> _files = {};
  bool _shouldFail = false;

  /// Set whether operations should fail (for testing error handling)
  void setShouldFail(bool value) {
    _shouldFail = value;
  }

  @override
  Future<String?> uploadImage(
    String localPath,
    String fileName, {
    String folder = 'images',
  }) async {
    if (_shouldFail) return null;
    final url = 'https://mock-storage.com/$folder/$fileName';
    _files['$folder/$fileName'] = url;
    return url;
  }

  @override
  Future<bool> deleteImage(String fileName, {String folder = 'images'}) async {
    if (_shouldFail) return false;
    _files.remove('$folder/$fileName');
    return true;
  }

  @override
  Future<String?> getDownloadUrl(String fileName,
      {String folder = 'images'}) async {
    if (_shouldFail) return null;
    return _files['$folder/$fileName'];
  }

  @override
  Future<bool> checkConnection() async {
    if (_shouldFail) return false;
    return true;
  }
}
