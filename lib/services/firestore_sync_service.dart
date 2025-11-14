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

        // If there was a previous background, delete it from Storage
        // This happens when user removes background image
        deleteBackgroundImage(profile.id); // Non-blocking cleanup
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

      // Handle background image URL - explicitly delete if removed
      if (backgroundImageUrl != null && backgroundImageUrl.isNotEmpty) {
        cardAestheticsMap['backgroundImageUrl'] = backgroundImageUrl;
      } else if (profile.cardAesthetics.backgroundImagePath == null) {
        // Explicitly delete the field from Firestore when background is removed
        cardAestheticsMap['backgroundImageUrl'] = FieldValue.delete();
        developer.log(
          '🗑️ Marking backgroundImageUrl for deletion in Firestore',
          name: 'FirestoreSync.FieldDelete',
        );
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

      // Remove null values from top-level to save space
      data.removeWhere((key, value) => value == null);

      // Upload to Firestore using {uuid}_{type} format for document ID
      final firestoreDocId = '${profile.id}_${profile.type.name}';

      developer.log(
        '📤 Writing to Firestore collection: profiles/$firestoreDocId\n'
        '   • Profile UUID: ${profile.id}\n'
        '   • Profile Type: ${profile.type.name}',
        name: 'FirestoreSync.Write',
      );

      await _firestore
          .collection('profiles')
          .doc(firestoreDocId)
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

  /// Delete background image from Firebase Storage
  ///
  /// Removes the background image file from Storage
  /// Returns true if successful, false otherwise
  static Future<bool> deleteBackgroundImage(String profileId) async {
    try {
      developer.log(
        '🗑️ Deleting background image for profile: $profileId',
        name: 'FirestoreSync.BackgroundDelete',
      );

      final extensions = ['jpg', 'jpeg', 'png', 'webp'];
      bool deleted = false;

      for (final ext in extensions) {
        try {
          await _storage.ref().child('background_images/${profileId}_bg.$ext').delete();
          developer.log(
            '✅ Deleted background image: ${profileId}_bg.$ext',
            name: 'FirestoreSync.BackgroundDelete',
          );
          deleted = true;
          break; // Stop after first successful deletion
        } catch (e) {
          // Continue trying other extensions
        }
      }

      if (!deleted) {
        developer.log(
          'ℹ️ No background image found to delete for: $profileId',
          name: 'FirestoreSync.BackgroundDelete',
        );
      }

      return deleted;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Background image deletion failed for $profileId',
        name: 'FirestoreSync.BackgroundDelete',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Fetch profile from Firestore by profile ID
  ///
  /// Production-ready method with comprehensive logging.
  /// Returns ProfileData or null if not found or on error.
  ///
  /// Use cases:
  /// - Loading received contacts from device contact scan
  /// - Fetching shared profile details
  /// - Profile preview in history
  static Future<ProfileData?> getProfileById(String profileId) async {
    final fetchStartTime = DateTime.now();

    try {
      developer.log(
        '📥 Starting SMART Firestore profile fetch\n'
        '   • Original Profile ID: $profileId\n'
        '   • Collection: profiles\n'
        '   • Timestamp: ${fetchStartTime.toIso8601String()}\n'
        '   • Attempting multiple fetch strategies...',
        name: 'FirestoreSync.GetProfile',
      );

      DocumentSnapshot? doc;
      String? successfulId;

      // STRATEGY 1: Try exact ID match (most common case)
      developer.log('   🔍 Strategy 1: Trying exact ID match...', name: 'FirestoreSync.GetProfile');
      doc = await _firestore.collection('profiles').doc(profileId).get();

      if (doc.exists) {
        successfulId = profileId;
        developer.log('   ✅ Strategy 1 SUCCESS!', name: 'FirestoreSync.GetProfile');
      } else {
        developer.log('   ❌ Strategy 1 failed - document not found', name: 'FirestoreSync.GetProfile');

        // STRATEGY 2: Try stripping type suffix
        final uuidMatch = RegExp(r'^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{10,12})', caseSensitive: false).firstMatch(profileId);
        if (uuidMatch != null) {
          final uuidOnly = uuidMatch.group(1)!;
          developer.log('   🔍 Strategy 2: Trying UUID only ($uuidOnly)...', name: 'FirestoreSync.GetProfile');

          doc = await _firestore.collection('profiles').doc(uuidOnly).get();

          if (doc.exists) {
            successfulId = uuidOnly;
            developer.log('   ✅ Strategy 2 SUCCESS!', name: 'FirestoreSync.GetProfile');
          } else {
            developer.log('   ❌ Strategy 2 failed', name: 'FirestoreSync.GetProfile');

            // STRATEGY 3: Try all type suffixes
            developer.log('   🔍 Strategy 3: Trying all type suffixes...', name: 'FirestoreSync.GetProfile');
            for (final type in ['personal', 'professional', 'custom']) {
              final idWithType = '${uuidOnly}_$type';
              developer.log('      • Trying: $idWithType', name: 'FirestoreSync.GetProfile');

              doc = await _firestore.collection('profiles').doc(idWithType).get();

              if (doc.exists) {
                successfulId = idWithType;
                developer.log('   ✅ Strategy 3 SUCCESS with $type type!', name: 'FirestoreSync.GetProfile');
                break;
              }
            }

            if (doc == null || !doc.exists) {
              developer.log('   ❌ Strategy 3 failed - tried all type suffixes', name: 'FirestoreSync.GetProfile');

              // STRATEGY 4: Query by 'id' field
              developer.log('   🔍 Strategy 4: Querying by id field...', name: 'FirestoreSync.GetProfile');
              try {
                final querySnapshot = await _firestore
                  .collection('profiles')
                  .where('id', isEqualTo: uuidOnly)
                  .limit(1)
                  .get();

                if (querySnapshot.docs.isNotEmpty) {
                  doc = querySnapshot.docs.first;
                  successfulId = doc.id;
                  developer.log('   ✅ Strategy 4 SUCCESS! Found via query with doc ID: $successfulId', name: 'FirestoreSync.GetProfile');
                } else {
                  developer.log('   ❌ Strategy 4 failed - no documents match id field', name: 'FirestoreSync.GetProfile');
                }
              } catch (e) {
                developer.log('   ❌ Strategy 4 exception: $e', name: 'FirestoreSync.GetProfile');
              }
            }
          }
        }
      }

      final fetchDuration = DateTime.now().difference(fetchStartTime).inMilliseconds;

      // Check if we found anything
      if (doc == null || !doc.exists) {
        developer.log(
          '⚠️ Profile not found in Firestore after trying ALL strategies\n'
          '   • Original ID: $profileId\n'
          '   • Fetch Duration: ${fetchDuration}ms\n'
          '   • This profile has NOT been synced to Firestore\n'
          '   • Falling back to vCard data...',
          name: 'FirestoreSync.GetProfile',
        );
        return null;
      }

      developer.log(
        '✅ Document found in Firestore!\n'
        '   • Original ID: $profileId\n'
        '   • Successful ID: $successfulId\n'
        '   • Fetch Duration: ${fetchDuration}ms\n'
        '   • Document Size: ${doc.data().toString().length} bytes\n'
        '   • Starting deserialization...',
        name: 'FirestoreSync.GetProfile',
      );

      final data = doc.data()! as Map<String, dynamic>;

      // Log field presence for debugging
      developer.log(
        '📋 Profile data fields:\n'
        '   • name: ${data['name'] != null ? "✓" : "✗"}\n'
        '   • email: ${data['email'] != null ? "✓" : "✗"}\n'
        '   • phone: ${data['phone'] != null ? "✓" : "✗"}\n'
        '   • company: ${data['company'] != null ? "✓" : "✗"}\n'
        '   • profileImageUrl: ${data['profileImageUrl'] != null ? "✓" : "✗"}\n'
        '   • cardAesthetics: ${data['cardAesthetics'] != null ? "✓" : "✗"}\n'
        '   • socialMedia: ${(data['socialMedia'] as Map?)?.length ?? 0} links',
        name: 'FirestoreSync.GetProfile',
      );

      // Determine profile type
      final profileType = ProfileType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ProfileType.personal,
      );

      // Log cardAesthetics field presence for debugging
      if (data['cardAesthetics'] != null) {
        final aesthetics = data['cardAesthetics'] as Map;
        developer.log(
          '🎨 CardAesthetics fields in Firestore:\n'
          '   • primaryColor: ${aesthetics['primaryColor'] != null ? "✓" : "✗"}\n'
          '   • secondaryColor: ${aesthetics['secondaryColor'] != null ? "✓" : "✗"}\n'
          '   • backgroundImageUrl: ${aesthetics['backgroundImageUrl'] != null ? "✓ (${aesthetics['backgroundImageUrl']})" : "✗"}\n'
          '   • backgroundColor: ${aesthetics['backgroundColor'] != null ? "✓" : "✗"}\n'
          '   • blurLevel: ${aesthetics['blurLevel']}',
          name: 'FirestoreSync.GetProfile',
        );
      }

      // Parse custom links with backward compatibility
      List<CustomLink> customLinks = [];
      if (data['customLinks'] != null) {
        customLinks = (data['customLinks'] as List)
            .map((linkJson) => CustomLink.fromJson(linkJson))
            .toList();
      }

      // Convert Firestore data back to ProfileData
      final profile = ProfileData(
        id: data['id'] ?? profileId,
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
        profileImagePath: data['profileImageUrl'], // Firestore uses 'profileImageUrl'
        cardAesthetics: data['cardAesthetics'] != null
            ? CardAesthetics.fromJson(
                Map<String, dynamic>.from(data['cardAesthetics']))
            : CardAesthetics.defaultForType(profileType),
        lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isActive: data['isActive'] ?? false,
      );

      // Log profile image URL mapping
      developer.log(
        '🖼️ Profile image URL from Firestore:\n'
        '   • profileImageUrl field in Firestore: ${data['profileImageUrl'] ?? "NULL"}\n'
        '   • Mapped to profileImagePath: ${data['profileImageUrl'] ?? "NULL"}\n'
        '   • Is network URL: ${data['profileImageUrl']?.toString().startsWith('http') ?? false}',
        name: 'FirestoreSync.GetProfile',
      );

      final totalDuration = DateTime.now().difference(fetchStartTime).inMilliseconds;

      developer.log(
        '✅ Profile successfully fetched and deserialized\n'
        '   • Profile ID: $profileId\n'
        '   • Name: ${profile.name}\n'
        '   • Type: ${profile.type.label}\n'
        '   • Email: ${profile.email ?? "NULL"}\n'
        '   • Phone: ${profile.phone ?? "NULL"}\n'
        '   • Company: ${profile.company ?? "NULL"}\n'
        '   • Title: ${profile.title ?? "NULL"}\n'
        '   • Image URL: ${profile.profileImagePath ?? "NULL"}\n'
        '   • Social Links: ${profile.socialMedia.length}\n'
        '   • Total Duration: ${totalDuration}ms',
        name: 'FirestoreSync.GetProfile',
      );

      return profile;
    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(fetchStartTime).inMilliseconds;

      developer.log(
        '❌ Profile fetch failed\n'
        '   • Profile ID: $profileId\n'
        '   • Duration: ${errorDuration}ms\n'
        '   • Error Type: ${e.runtimeType}\n'
        '   • Error Message: $e\n'
        '   • Possible causes: Network error, malformed data, permission denied',
        name: 'FirestoreSync.GetProfile',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Fetch profile from Firestore (legacy method for backward compatibility)
  ///
  /// @deprecated Use getProfileById() instead for better logging
  static Future<ProfileData?> fetchProfileFromFirestore(String uuid) async {
    return getProfileById(uuid);
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
