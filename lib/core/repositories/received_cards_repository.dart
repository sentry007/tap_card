/// Received Cards Repository
///
/// Persistent storage for received card UIDs with Firestore sync support.
///
/// **Architecture:**
/// - Single source of truth for "what cards I've received"
/// - Independent of device contacts (vCards can be deleted separately)
/// - Syncs to Firestore for cross-device access
/// - Deduplication by UID
///
/// **Use Cases:**
/// - Retain history even when vCard is deleted from device
/// - Cross-device sync of received contacts
/// - Analytics: unique contacts received
/// - Re-save vCard to new device
library;

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_models.dart';
import '../../models/history_models.dart';

/// Metadata for a received card
/// Stored alongside UID for offline fallback display
class ReceivedCardMetadata {
  final String uid;
  final String name;
  final String? company;
  final String? title;
  final ProfileType profileType;
  final DateTime receivedAt;
  final DateTime lastUpdated;
  final ShareMethod shareMethod;

  const ReceivedCardMetadata({
    required this.uid,
    required this.name,
    this.company,
    this.title,
    required this.profileType,
    required this.receivedAt,
    required this.lastUpdated,
    required this.shareMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'company': company,
      'title': title,
      'profileType': profileType.name,
      'receivedAt': receivedAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'shareMethod': shareMethod.name,
    };
  }

  factory ReceivedCardMetadata.fromJson(Map<String, dynamic> json) {
    return ReceivedCardMetadata(
      uid: json['uid'],
      name: json['name'],
      company: json['company'],
      title: json['title'],
      profileType: ProfileType.values.firstWhere(
        (e) => e.name == json['profileType'],
        orElse: () => ProfileType.personal,
      ),
      receivedAt: DateTime.parse(json['receivedAt']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      shareMethod: ShareMethod.values.firstWhere(
        (e) => e.name == json['shareMethod'],
        orElse: () => ShareMethod.nfc,
      ),
    );
  }
}

/// Repository for managing received cards UIDs
///
/// Provides persistent storage with Firestore sync capability
class ReceivedCardsRepository {
  static final ReceivedCardsRepository _instance = ReceivedCardsRepository._internal();
  factory ReceivedCardsRepository() => _instance;
  ReceivedCardsRepository._internal();

  static const String _uidsKey = 'received_card_uids';
  static const String _metadataKey = 'received_card_metadata';

  /// Add a received card UID with optional profile metadata
  ///
  /// **Behavior:**
  /// - Deduplicates by UID (updates if already exists)
  /// - Stores minimal metadata for offline fallback
  /// - Returns true if newly added, false if updated
  Future<bool> addReceivedCard(
    String uid, {
    required ProfileData profile,
    required ShareMethod shareMethod,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current UIDs
      final uids = await getAllReceivedUids();
      final isNew = !uids.contains(uid);

      if (isNew) {
        uids.add(uid);
        await prefs.setStringList(_uidsKey, uids);
      }

      // Store/update metadata
      final metadata = await _getAllMetadata();
      metadata[uid] = ReceivedCardMetadata(
        uid: uid,
        name: profile.name,
        company: profile.company,
        title: profile.title,
        profileType: profile.type,
        receivedAt: isNew ? DateTime.now() :
          (metadata[uid]?.receivedAt ?? DateTime.now()),
        lastUpdated: DateTime.now(),
        shareMethod: shareMethod,
      );

      await _saveMetadata(metadata);

      developer.log(
        '${isNew ? '➕ Added' : '🔄 Updated'} received card UID\n'
        '   • UID: $uid\n'
        '   • Name: ${profile.name}\n'
        '   • Total cards: ${uids.length}',
        name: 'ReceivedCardsRepo.Add',
      );

      return isNew;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Failed to add received card UID: $uid',
        name: 'ReceivedCardsRepo.Add',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Remove a received card UID
  ///
  /// **Use Cases:**
  /// - User explicitly deletes contact from app history
  /// - Cleanup of invalid/test entries
  ///
  /// **Note:** This does NOT delete device vCard or Firestore profile
  Future<bool> removeReceivedCard(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove from UIDs
      final uids = await getAllReceivedUids();
      final wasPresent = uids.remove(uid);

      if (wasPresent) {
        await prefs.setStringList(_uidsKey, uids);

        // Remove metadata
        final metadata = await _getAllMetadata();
        metadata.remove(uid);
        await _saveMetadata(metadata);

        developer.log(
          '🗑️ Removed received card UID\n'
          '   • UID: $uid\n'
          '   • Remaining cards: ${uids.length}',
          name: 'ReceivedCardsRepo.Remove',
        );
      }

      return wasPresent;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Failed to remove received card UID: $uid',
        name: 'ReceivedCardsRepo.Remove',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Get all received card UIDs (chronological order)
  Future<List<String>> getAllReceivedUids() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_uidsKey) ?? [];
    } catch (e) {
      developer.log(
        '❌ Failed to load received UIDs',
        name: 'ReceivedCardsRepo.GetAll',
        error: e,
      );
      return [];
    }
  }

  /// Get metadata for a specific UID
  Future<ReceivedCardMetadata?> getMetadata(String uid) async {
    try {
      final allMetadata = await _getAllMetadata();
      return allMetadata[uid];
    } catch (e) {
      developer.log(
        '❌ Failed to get metadata for UID: $uid',
        name: 'ReceivedCardsRepo.GetMetadata',
        error: e,
      );
      return null;
    }
  }

  /// Get all metadata (map: uid → metadata)
  Future<Map<String, ReceivedCardMetadata>> _getAllMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_metadataKey);

      if (jsonString == null) return {};

      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return jsonMap.map((uid, metaJson) => MapEntry(
        uid,
        ReceivedCardMetadata.fromJson(metaJson as Map<String, dynamic>),
      ));
    } catch (e) {
      developer.log(
        '❌ Failed to load metadata',
        name: 'ReceivedCardsRepo.LoadMetadata',
        error: e,
      );
      return {};
    }
  }

  /// Save metadata to storage
  Future<void> _saveMetadata(Map<String, ReceivedCardMetadata> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonMap = metadata.map((uid, meta) => MapEntry(uid, meta.toJson()));
      await prefs.setString(_metadataKey, jsonEncode(jsonMap));
    } catch (e) {
      developer.log(
        '❌ Failed to save metadata',
        name: 'ReceivedCardsRepo.SaveMetadata',
        error: e,
      );
    }
  }

  /// Check if a card UID has been received
  Future<bool> hasReceivedCard(String uid) async {
    final uids = await getAllReceivedUids();
    return uids.contains(uid);
  }

  /// Get count of received cards
  Future<int> getReceivedCardCount() async {
    final uids = await getAllReceivedUids();
    return uids.length;
  }

  /// Clear all received cards (destructive!)
  ///
  /// **Use Cases:**
  /// - User signs out / resets app
  /// - Testing / development
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_uidsKey);
      await prefs.remove(_metadataKey);

      developer.log(
        '🧹 Cleared all received cards',
        name: 'ReceivedCardsRepo.Clear',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to clear received cards',
        name: 'ReceivedCardsRepo.Clear',
        error: e,
      );
    }
  }

  /// Sync received card UIDs to Firestore user document
  ///
  /// **Firestore Structure:**
  /// ```
  /// users/{userUid}/
  ///   - receivedCardUids: [uid1, uid2, ...]
  ///   - receivedCardMetadata: {uid1: {...}, uid2: {...}}
  ///   - lastSynced: timestamp
  /// ```
  ///
  /// **Sync Strategy:**
  /// - Last-write-wins for conflict resolution
  /// - Bidirectional: push local → pull remote if remote is newer
  Future<void> syncToFirestore(String userUid) async {
    try {
      // TODO: Implement Firestore sync in Phase 4
      // 1. Get local UIDs and metadata
      // 2. Fetch remote from Firestore users/{userUid}
      // 3. Merge using last-write-wins (compare lastUpdated)
      // 4. Push merged data to Firestore
      // 5. Update local storage with merged data

      developer.log(
        '⚠️ Firestore sync not yet implemented (Phase 4)\n'
        '   • User UID: $userUid',
        name: 'ReceivedCardsRepo.Sync',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Firestore sync failed for user: $userUid',
        name: 'ReceivedCardsRepo.Sync',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Import received cards from Firestore (for new device setup)
  Future<void> importFromFirestore(String userUid) async {
    try {
      // TODO: Implement in Phase 4
      developer.log(
        '⚠️ Firestore import not yet implemented (Phase 4)\n'
        '   • User UID: $userUid',
        name: 'ReceivedCardsRepo.Import',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Firestore import failed for user: $userUid',
        name: 'ReceivedCardsRepo.Import',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
