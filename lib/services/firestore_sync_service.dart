/// Firestore Sync Service
///
/// Handles all Firebase Firestore and Storage operations:
/// - Profile syncing to Firestore
/// - Image uploads to Firebase Storage
/// - Profile fetching and deletion
/// - Background sync with error handling
library;

import 'dart:io';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tap_card/core/models/profile_models.dart';
import 'package:tap_card/services/sync_log_service.dart';

/// Service for syncing profiles with Firebase Firestore and Storage
class FirestoreSyncService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  /// Sync profile to Firestore
  ///
  /// Uploads profile data to Firestore collection 'profiles'
  /// Also uploads profile image and background image to Firebase Storage if available
  /// Returns map with uploaded URLs if sync succeeds, null otherwise
  /// Map keys: 'profileImageUrl', 'backgroundImageUrl'
  static Future<Map<String, String?>?> syncProfileToFirestore(ProfileData profile) async {
    final syncStartTime = DateTime.now();

    try {
      developer.log(
        '🔄 Starting Firestore sync for profile: ${profile.id}\n'
        '   • Profile Name: ${profile.name}\n'
        '   • Profile Type: ${profile.type.name}\n'
        '   • Has Image: ${profile.profileImagePath != null}',
        name: 'FirestoreSync.Start',
      );

      // Upload profile image first (if exists and is local path)
      String? imageUrl;
      if (profile.profileImagePath != null &&
          profile.profileImagePath!.isNotEmpty) {
        // Check if it's already a Firebase URL
        if (profile.profileImagePath!.startsWith('http')) {
          imageUrl = profile.profileImagePath;
        } else {
          // Upload local file to Storage
          imageUrl = await uploadProfileImage(
            profile.profileImagePath!,
            profile.id
          );
        }
      }

      // Upload background image if exists and is local path
      String? backgroundImageUrl;
      if (profile.cardAesthetics.backgroundImagePath != null &&
          profile.cardAesthetics.backgroundImagePath!.isNotEmpty) {
        developer.log(
          '🖼️ Background image path found: ${profile.cardAesthetics.backgroundImagePath}',
          name: 'FirestoreSync.BackgroundCheck',
        );

        // Check if it's already a Firebase URL
        if (profile.cardAesthetics.backgroundImagePath!.startsWith('http')) {
          backgroundImageUrl = profile.cardAesthetics.backgroundImagePath;
          developer.log(
            '✅ Using existing Firebase URL for background image',
            name: 'FirestoreSync.BackgroundCheck',
          );
        } else {
          // Upload local file to Storage
          developer.log(
            '📤 Triggering background image upload...',
            name: 'FirestoreSync.BackgroundCheck',
          );
          backgroundImageUrl = await uploadBackgroundImage(
            profile.cardAesthetics.backgroundImagePath!,
            profile.id
          );

          if (backgroundImageUrl != null) {
            developer.log(
              '✅ Background image uploaded, URL: $backgroundImageUrl',
              name: 'FirestoreSync.BackgroundCheck',
            );
          } else {
            developer.log(
              '❌ Background image upload returned null',
              name: 'FirestoreSync.BackgroundCheck',
            );
          }
        }
      } else {
        developer.log(
          'ℹ️ No background image to upload for profile: ${profile.id}',
          name: 'FirestoreSync.BackgroundCheck',
        );
      }

      // Build cardAesthetics map without null values
      final cardAestheticsMap = <String, dynamic>{
        'primaryColor': profile.cardAesthetics.primaryColor.value,
        'secondaryColor': profile.cardAesthetics.secondaryColor.value,
        'borderColor': profile.cardAesthetics.borderColor.value,
        'blurLevel': profile.cardAesthetics.blurLevel,
      };

      // Add optional fields only if not null
      if (profile.cardAesthetics.backgroundColor != null) {
        cardAestheticsMap['backgroundColor'] = profile.cardAesthetics.backgroundColor!.value;
      }
      if (backgroundImageUrl != null && backgroundImageUrl.isNotEmpty) {
        cardAestheticsMap['backgroundImageUrl'] = backgroundImageUrl;
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
        'profileImageUrl': imageUrl,
        'cardAesthetics': cardAestheticsMap,
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': profile.isActive,
      };

      // Remove null values from top-level to save space
      data.removeWhere((key, value) => value == null);

      // Upload to Firestore
      developer.log(
        '📤 Writing to Firestore collection: profiles/${profile.id}',
        name: 'FirestoreSync.Write',
      );

      await _firestore
          .collection('profiles')
          .doc(profile.id)
          .set(data, SetOptions(merge: true));

      final syncDuration = DateTime.now().difference(syncStartTime).inMilliseconds;

      developer.log(
        '✅ Profile synced to Firestore: ${profile.id}\n'
        '   • Name: ${profile.name}\n'
        '   • Type: ${profile.type.name}\n'
        '   • Profile Image: ${imageUrl != null ? "Uploaded" : "None"}\n'
        '   • Background Image: ${backgroundImageUrl != null ? "Uploaded" : "None"}\n'
        '   • Duration: ${syncDuration}ms\n'
        '   • Document Size: ${data.toString().length} bytes',
        name: 'FirestoreSync.Success',
      );

      // Log to sync history
      await SyncLogService.logSync(
        profileId: profile.id,
        profileName: profile.name,
        operation: 'sync',
        success: true,
        duration: syncDuration,
      );

      // Return uploaded URLs
      return {
        'profileImageUrl': imageUrl,
        'backgroundImageUrl': backgroundImageUrl,
      };
    } catch (e, stackTrace) {
      final syncDuration = DateTime.now().difference(syncStartTime).inMilliseconds;

      developer.log(
        '❌ Firestore sync failed for ${profile.id}\n'
        '   • Profile Name: ${profile.name}\n'
        '   • Duration: ${syncDuration}ms\n'
        '   • Error Type: ${e.runtimeType}\n'
        '   • Error Message: $e',
        name: 'FirestoreSync.Error',
        error: e,
        stackTrace: stackTrace,
      );

      // Log to sync history
      await SyncLogService.logSync(
        profileId: profile.id,
        profileName: profile.name,
        operation: 'sync',
        success: false,
        errorMessage: e.toString(),
        duration: syncDuration,
      );

      return null;
    }
  }

  /// Upload profile image to Firebase Storage
  ///
  /// Takes local file path and uploads to Storage bucket
  /// Returns download URL or null if upload fails
  static Future<String?> uploadProfileImage(
    String localPath,
    String profileId,
  ) async {
    try {
      final file = File(localPath);

      // Check if file exists
      if (!await file.exists()) {
        developer.log(
          '⚠️ Image file not found: $localPath',
          name: 'FirestoreSync.ImageUpload',
        );
        return null;
      }

      developer.log(
        '📤 Uploading image for profile: $profileId',
        name: 'FirestoreSync.ImageUpload',
      );

      // Get file extension
      final extension = localPath.split('.').last.toLowerCase();
      final fileName = '$profileId.$extension';

      // Upload to Storage
      final ref = _storage.ref().child('profile_images/$fileName');
      final uploadTask = await ref.putFile(file);

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final fileSize = await file.length();
      developer.log(
        '✅ Image uploaded successfully\n'
        '   • Profile: $profileId\n'
        '   • Size: ${(fileSize / 1024).toStringAsFixed(2)} KB\n'
        '   • URL: $downloadUrl',
        name: 'FirestoreSync.ImageUpload',
      );

      return downloadUrl;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Image upload failed for $profileId',
        name: 'FirestoreSync.ImageUpload',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Upload background image to Firebase Storage
  ///
  /// Takes local file path and uploads to Storage bucket
  /// Returns download URL or null if upload fails
  static Future<String?> uploadBackgroundImage(
    String localPath,
    String profileId,
  ) async {
    try {
      final file = File(localPath);

      // Check if file exists
      if (!await file.exists()) {
        developer.log(
          '⚠️ Background image file not found: $localPath',
          name: 'FirestoreSync.BackgroundImageUpload',
        );
        return null;
      }

      developer.log(
        '📤 Uploading background image for profile: $profileId',
        name: 'FirestoreSync.BackgroundImageUpload',
      );

      // Get file extension
      final extension = localPath.split('.').last.toLowerCase();
      final fileName = '${profileId}_bg.$extension';

      // Upload to Storage
      final ref = _storage.ref().child('background_images/$fileName');
      final uploadTask = await ref.putFile(file);

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final fileSize = await file.length();
      developer.log(
        '✅ Background image uploaded successfully\n'
        '   • Profile: $profileId\n'
        '   • Size: ${(fileSize / 1024).toStringAsFixed(2)} KB\n'
        '   • URL: $downloadUrl',
        name: 'FirestoreSync.BackgroundImageUpload',
      );

      return downloadUrl;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Background image upload failed for $profileId',
        name: 'FirestoreSync.BackgroundImageUpload',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Fetch profile from Firestore (for testing)
  ///
  /// Returns ProfileData or null if not found
  static Future<ProfileData?> fetchProfileFromFirestore(String uuid) async {
    try {
      developer.log(
        '📥 Fetching profile from Firestore: $uuid',
        name: 'FirestoreSync.Fetch',
      );

      final doc = await _firestore.collection('profiles').doc(uuid).get();

      if (!doc.exists) {
        developer.log(
          '⚠️ Profile not found in Firestore: $uuid',
          name: 'FirestoreSync.Fetch',
        );
        return null;
      }

      final data = doc.data()!;

      // Convert Firestore data back to ProfileData
      // Note: This is a simplified conversion, adjust as needed
      final profile = ProfileData(
        id: data['id'] ?? uuid,
        uid: data['uid'],
        type: ProfileType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => ProfileType.personal,
        ),
        name: data['name'] ?? '',
        title: data['title'],
        company: data['company'],
        phone: data['phone'],
        email: data['email'],
        website: data['website'],
        socialMedia: Map<String, String>.from(data['socialMedia'] ?? {}),
        profileImagePath: data['profileImageUrl'],
        cardAesthetics: data['cardAesthetics'] != null
            ? CardAesthetics.fromJson(
                Map<String, dynamic>.from(data['cardAesthetics']))
            : CardAesthetics.defaultForType(
                ProfileType.values.firstWhere(
                  (e) => e.name == data['type'],
                  orElse: () => ProfileType.personal,
                ),
              ),
        lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isActive: data['isActive'] ?? false,
      );

      developer.log(
        '✅ Profile fetched from Firestore: ${profile.name}',
        name: 'FirestoreSync.Fetch',
      );

      return profile;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Fetch failed for $uuid',
        name: 'FirestoreSync.Fetch',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Delete profile from Firestore
  ///
  /// Removes profile document and associated image from Storage
  /// Returns true if successful, false otherwise
  static Future<bool> deleteProfileFromFirestore(String uuid) async {
    try {
      developer.log(
        '🗑️ Deleting profile from Firestore: $uuid',
        name: 'FirestoreSync.Delete',
      );

      // Delete Firestore document
      await _firestore.collection('profiles').doc(uuid).delete();

      // Try to delete associated images from Storage
      // (ignore errors if image doesn't exist)
      try {
        final extensions = ['jpg', 'jpeg', 'png', 'webp'];
        for (final ext in extensions) {
          try {
            await _storage.ref().child('profile_images/$uuid.$ext').delete();
            developer.log(
              '✅ Deleted image: profile_images/$uuid.$ext',
              name: 'FirestoreSync.Delete',
            );
            break; // Stop after first successful deletion
          } catch (_) {
            // Image with this extension doesn't exist, try next
          }
        }
      } catch (e) {
        developer.log(
          '⚠️ Could not delete image for $uuid (may not exist)',
          name: 'FirestoreSync.Delete',
        );
      }

      developer.log(
        '✅ Profile deleted from Firestore: $uuid',
        name: 'FirestoreSync.Delete',
      );

      return true;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Delete failed for $uuid',
        name: 'FirestoreSync.Delete',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Batch sync multiple profiles to Firestore
  ///
  /// Useful for initial migration or bulk updates
  /// Returns number of successfully synced profiles
  static Future<int> batchSyncProfiles(List<ProfileData> profiles) async {
    int successCount = 0;

    developer.log(
      '📦 Starting batch sync for ${profiles.length} profiles',
      name: 'FirestoreSync.Batch',
    );

    for (final profile in profiles) {
      final syncResult = await syncProfileToFirestore(profile);
      if (syncResult != null) {
        successCount++;
      }

      // Add small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    developer.log(
      '✅ Batch sync complete: $successCount/${profiles.length} successful',
      name: 'FirestoreSync.Batch',
    );

    return successCount;
  }

  /// Check if Firestore is accessible
  ///
  /// Returns true if can connect to Firestore, false otherwise
  static Future<bool> checkConnection() async {
    try {
      // Try to read from Firestore (will fail if no connection)
      await _firestore
          .collection('profiles')
          .limit(1)
          .get(const GetOptions(source: Source.server));

      developer.log(
        '✅ Firestore connection OK',
        name: 'FirestoreSync.Connection',
      );
      return true;
    } catch (e) {
      developer.log(
        '❌ Firestore connection failed',
        name: 'FirestoreSync.Connection',
        error: e,
      );
      return false;
    }
  }
}
