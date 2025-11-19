/// Firebase Profile Repository Implementation
///
/// Stores profiles in Firestore and images in Firebase Storage
/// Migrates logic from FirestoreSyncService into clean repository pattern
library;

import 'dart:io';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/profile_models.dart';
import 'profile_repository.dart';

/// Repository implementation using Firebase (Firestore + Storage)
class FirebaseProfileRepository implements ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirebaseProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<List<ProfileData>> getAllProfiles() async {
    try {
      developer.log(
        '📥 Fetching all profiles from Firestore',
        name: 'FirebaseProfileRepo.GetAll',
      );

      // Note: This would need a userId parameter in production
      // For now, assuming we query by current user
      final querySnapshot = await _firestore
          .collection('profiles')
          .get();

      final profiles = querySnapshot.docs
          .map((doc) => _documentToProfile(doc))
          .whereType<ProfileData>() // Filter out nulls
          .toList();

      developer.log(
        '✅ Fetched ${profiles.length} profiles from Firestore',
        name: 'FirebaseProfileRepo.GetAll',
      );

      return profiles;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error fetching profiles from Firestore',
        name: 'FirebaseProfileRepo.GetAll',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  Future<ProfileData?> getProfileById(String id) async {
    final fetchStartTime = DateTime.now();

    try {
      developer.log(
        '📥 Fetching profile from Firestore: $id',
        name: 'FirebaseProfileRepo.GetById',
      );

      DocumentSnapshot? doc;
      String? successfulId;

      // STRATEGY 1: Try exact ID match
      doc = await _firestore.collection('profiles').doc(id).get();

      if (doc.exists) {
        successfulId = id;
      } else {
        // STRATEGY 2: Try stripping type suffix
        final uuidMatch = RegExp(
                r'^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{10,12})',
                caseSensitive: false)
            .firstMatch(id);

        if (uuidMatch != null) {
          final uuidOnly = uuidMatch.group(1)!;

          // Try UUID only
          doc = await _firestore.collection('profiles').doc(uuidOnly).get();

          if (doc.exists) {
            successfulId = uuidOnly;
          } else {
            // STRATEGY 3: Try all type suffixes
            for (final type in ['personal', 'professional', 'custom']) {
              final idWithType = '${uuidOnly}_$type';
              doc = await _firestore.collection('profiles').doc(idWithType).get();

              if (doc.exists) {
                successfulId = idWithType;
                break;
              }
            }

            // STRATEGY 4: Query by 'id' field
            if (doc == null || !doc.exists) {
              final querySnapshot = await _firestore
                  .collection('profiles')
                  .where('id', isEqualTo: uuidOnly)
                  .limit(1)
                  .get();

              if (querySnapshot.docs.isNotEmpty) {
                doc = querySnapshot.docs.first;
                successfulId = doc.id;
              }
            }
          }
        }
      }

      final fetchDuration = DateTime.now().difference(fetchStartTime).inMilliseconds;

      if (doc == null || !doc.exists) {
        developer.log(
          '⚠️  Profile not found in Firestore: $id (${fetchDuration}ms)',
          name: 'FirebaseProfileRepo.GetById',
        );
        return null;
      }

      developer.log(
        '✅ Profile found in Firestore: $successfulId (${fetchDuration}ms)',
        name: 'FirebaseProfileRepo.GetById',
      );

      return _documentToProfile(doc);
    } catch (e, stackTrace) {
      final errorDuration =
          DateTime.now().difference(fetchStartTime).inMilliseconds;
      developer.log(
        '❌ Error fetching profile: $id (${errorDuration}ms)',
        name: 'FirebaseProfileRepo.GetById',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<ProfileData?> getProfileByType(ProfileType type) async {
    try {
      // In production, add userId parameter
      final querySnapshot = await _firestore
          .collection('profiles')
          .where('type', isEqualTo: type.name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return _documentToProfile(querySnapshot.docs.first);
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error fetching profile by type: ${type.name}',
        name: 'FirebaseProfileRepo.GetByType',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<ProfileData> createProfile(ProfileData profile) async {
    try {
      final data = await _profileToDocument(profile);
      final docId = '${profile.id}_${profile.type.name}';

      await _firestore.collection('profiles').doc(docId).set(data);

      developer.log(
        '✅ Profile created in Firestore: ${profile.name}',
        name: 'FirebaseProfileRepo.Create',
      );

      return profile;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error creating profile in Firestore',
        name: 'FirebaseProfileRepo.Create',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to create profile');
    }
  }

  @override
  Future<ProfileData> updateProfile(ProfileData profile) async {
    final syncStartTime = DateTime.now();

    try {
      developer.log(
        '🔄 Updating profile in Firestore: ${profile.id}',
        name: 'FirebaseProfileRepo.Update',
      );

      final data = await _profileToDocument(profile);
      final docId = '${profile.id}_${profile.type.name}';

      await _firestore
          .collection('profiles')
          .doc(docId)
          .set(data, SetOptions(merge: true));

      final syncDuration =
          DateTime.now().difference(syncStartTime).inMilliseconds;

      developer.log(
        '✅ Profile updated in Firestore: ${profile.name} (${syncDuration}ms)',
        name: 'FirebaseProfileRepo.Update',
      );

      return profile;
    } catch (e, stackTrace) {
      final syncDuration =
          DateTime.now().difference(syncStartTime).inMilliseconds;
      developer.log(
        '❌ Error updating profile (${syncDuration}ms)',
        name: 'FirebaseProfileRepo.Update',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to update profile');
    }
  }

  @override
  Future<bool> deleteProfile(String id) async {
    try {
      developer.log(
        '🗑️  Deleting profile from Firestore: $id',
        name: 'FirebaseProfileRepo.Delete',
      );

      // Delete Firestore document
      await _firestore.collection('profiles').doc(id).delete();

      // Try to delete associated images from Storage
      await _deleteProfileImages(id);

      developer.log(
        '✅ Profile deleted from Firestore: $id',
        name: 'FirebaseProfileRepo.Delete',
      );

      return true;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error deleting profile',
        name: 'FirebaseProfileRepo.Delete',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<int> batchSyncProfiles(List<ProfileData> profiles) async {
    int successCount = 0;

    developer.log(
      '📦 Starting batch sync for ${profiles.length} profiles',
      name: 'FirebaseProfileRepo.BatchSync',
    );

    for (final profile in profiles) {
      try {
        await updateProfile(profile);
        successCount++;

        // Add small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        developer.log(
          '⚠️  Failed to sync profile: ${profile.name}',
          name: 'FirebaseProfileRepo.BatchSync',
        );
      }
    }

    developer.log(
      '✅ Batch sync complete: $successCount/${profiles.length} successful',
      name: 'FirebaseProfileRepo.BatchSync',
    );

    return successCount;
  }

  @override
  Future<ProfileSettings> getSettings() async {
    // Firebase doesn't store settings - this is handled by local storage
    // Return default settings
    return ProfileSettings(activeProfileId: '');
  }

  @override
  Future<void> updateSettings(ProfileSettings settings) async {
    // Firebase doesn't store settings - this is handled by local storage
    // No-op for Firebase repository
  }

  @override
  Future<bool> checkConnection() async {
    try {
      await _firestore
          .collection('profiles')
          .limit(1)
          .get(const GetOptions(source: Source.server));

      developer.log(
        '✅ Firestore connection OK',
        name: 'FirebaseProfileRepo.Connection',
      );
      return true;
    } catch (e) {
      developer.log(
        '❌ Firestore connection failed',
        name: 'FirebaseProfileRepo.Connection',
        error: e,
      );
      return false;
    }
  }

  @override
  Future<void> clearAll() async {
    // Not recommended to delete from Firebase on sign-out
    // Firebase data should persist across sign-ins
    developer.log(
      'ℹ️  clearAll() called on Firebase repository - no action taken',
      name: 'FirebaseProfileRepo.ClearAll',
    );
  }

  // ========== Private Helper Methods ==========

  /// Convert ProfileData to Firestore document
  Future<Map<String, dynamic>> _profileToDocument(ProfileData profile) async {
    // Upload images if they're local files
    String? imageUrl;
    if (profile.profileImagePath != null &&
        profile.profileImagePath!.isNotEmpty) {
      if (profile.profileImagePath!.startsWith('http')) {
        imageUrl = profile.profileImagePath;
      } else {
        imageUrl = await _uploadProfileImage(
            profile.profileImagePath!, profile.id);
      }
    }

    String? backgroundImageUrl;
    if (profile.cardAesthetics.backgroundImagePath != null &&
        profile.cardAesthetics.backgroundImagePath!.isNotEmpty) {
      if (profile.cardAesthetics.backgroundImagePath!.startsWith('http')) {
        backgroundImageUrl = profile.cardAesthetics.backgroundImagePath;
      } else {
        backgroundImageUrl = await _uploadBackgroundImage(
            profile.cardAesthetics.backgroundImagePath!, profile.id);
      }
    }

    // Build cardAesthetics map
    final cardAestheticsMap = <String, dynamic>{
      'primaryColor': profile.cardAesthetics.primaryColor.toARGB32(),
      'secondaryColor': profile.cardAesthetics.secondaryColor.toARGB32(),
      'borderColor': profile.cardAesthetics.borderColor.toARGB32(),
      'blurLevel': profile.cardAesthetics.blurLevel,
    };

    if (profile.cardAesthetics.backgroundColor != null) {
      cardAestheticsMap['backgroundColor'] =
          profile.cardAesthetics.backgroundColor!.toARGB32();
    }

    if (backgroundImageUrl != null && backgroundImageUrl.isNotEmpty) {
      cardAestheticsMap['backgroundImageUrl'] = backgroundImageUrl;
    } else if (profile.cardAesthetics.backgroundImagePath == null) {
      cardAestheticsMap['backgroundImageUrl'] = FieldValue.delete();
    }

    // Convert profile to Firestore document
    final data = {
      'id': profile.id,
      'uid': profile.uid,
      'name': profile.name,
      'type': profile.type.name,
      'phone': profile.phone,
      'email': profile.email,
      'company': profile.company,
      'title': profile.title,
      'website': profile.website,
      'socialMedia': profile.socialMedia,
      'customLinks': profile.customLinks.map((link) => link.toJson()).toList(),
      'profileImageUrl': imageUrl,
      'cardAesthetics': cardAestheticsMap,
      'lastUpdated': FieldValue.serverTimestamp(),
      'isActive': profile.isActive,
    };

    // Remove null values
    data.removeWhere((key, value) => value == null);

    return data;
  }

  /// Convert Firestore document to ProfileData
  ProfileData? _documentToProfile(DocumentSnapshot doc) {
    try {
      if (!doc.exists) return null;

      final data = doc.data()! as Map<String, dynamic>;

      // Determine profile type
      final profileType = ProfileType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ProfileType.personal,
      );

      // Parse custom links
      List<CustomLink> customLinks = [];
      if (data['customLinks'] != null) {
        customLinks = (data['customLinks'] as List)
            .map((linkJson) => CustomLink.fromJson(linkJson))
            .toList();
      }

      return ProfileData(
        id: data['id'] ?? doc.id,
        uid: data['uid'],
        type: profileType,
        name: data['name'] ?? '',
        title: data['title'],
        company: data['company'],
        phone: data['phone'],
        email: data['email'],
        website: data['website'],
        socialMedia: Map<String, String>.from(data['socialMedia'] ?? {}),
        customLinks: customLinks,
        profileImagePath: data['profileImageUrl'],
        cardAesthetics: data['cardAesthetics'] != null
            ? CardAesthetics.fromJson(
                Map<String, dynamic>.from(data['cardAesthetics']))
            : CardAesthetics.defaultForType(profileType),
        lastUpdated:
            (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isActive: data['isActive'] ?? false,
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error converting document to profile: ${doc.id}',
        name: 'FirebaseProfileRepo.DocumentToProfile',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Upload profile image to Firebase Storage
  Future<String?> _uploadProfileImage(String localPath, String profileId) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final extension = localPath.split('.').last.toLowerCase();
      final fileName = '$profileId.$extension';

      final ref = _storage.ref().child('profile_images/$fileName');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      developer.log(
        '✅ Image uploaded successfully: $downloadUrl',
        name: 'FirebaseProfileRepo.ImageUpload',
      );

      return downloadUrl;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Image upload failed',
        name: 'FirebaseProfileRepo.ImageUpload',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Upload background image to Firebase Storage
  Future<String?> _uploadBackgroundImage(
      String localPath, String profileId) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final extension = localPath.split('.').last.toLowerCase();
      final fileName = '${profileId}_bg.$extension';

      final ref = _storage.ref().child('background_images/$fileName');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      developer.log(
        '✅ Background image uploaded successfully: $downloadUrl',
        name: 'FirebaseProfileRepo.BackgroundUpload',
      );

      return downloadUrl;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Background image upload failed',
        name: 'FirebaseProfileRepo.BackgroundUpload',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Delete profile images from Firebase Storage
  Future<void> _deleteProfileImages(String profileId) async {
    try {
      final extensions = ['jpg', 'jpeg', 'png', 'webp'];

      // Delete profile image
      for (final ext in extensions) {
        try {
          await _storage.ref().child('profile_images/$profileId.$ext').delete();
          developer.log(
            '✅ Deleted profile image: $profileId.$ext',
            name: 'FirebaseProfileRepo.DeleteImages',
          );
          break; // Found and deleted, stop trying other extensions
        } on FirebaseException catch (e) {
          // Gracefully handle file not found (404)
          if (e.code == 'object-not-found') {
            // This is fine - file doesn't exist, try next extension
            continue;
          }
          // Re-throw other Firebase errors (permission denied, network issues, etc.)
          rethrow;
        } catch (_) {
          // Continue trying other extensions for non-Firebase errors
          continue;
        }
      }

      // Delete background image
      for (final ext in extensions) {
        try {
          await _storage
              .ref()
              .child('background_images/${profileId}_bg.$ext')
              .delete();
          developer.log(
            '✅ Deleted background image: ${profileId}_bg.$ext',
            name: 'FirebaseProfileRepo.DeleteImages',
          );
          break; // Found and deleted, stop trying other extensions
        } on FirebaseException catch (e) {
          // Gracefully handle file not found (404)
          if (e.code == 'object-not-found') {
            // This is fine - file doesn't exist, try next extension
            continue;
          }
          // Re-throw other Firebase errors
          rethrow;
        } catch (_) {
          // Continue trying other extensions for non-Firebase errors
          continue;
        }
      }

      developer.log(
        'ℹ️  Image deletion complete for profile: $profileId',
        name: 'FirebaseProfileRepo.DeleteImages',
      );
    } catch (e, stackTrace) {
      // Only log actual errors, not missing files (404s are handled above)
      developer.log(
        '⚠️  Error during image deletion (unexpected error)',
        name: 'FirebaseProfileRepo.DeleteImages',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
