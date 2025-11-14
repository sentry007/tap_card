/// Profile Views Service
///
/// Fetches and streams profile view counts from Firestore
/// Provides real-time updates for analytics dashboard
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

/// Service for fetching profile view statistics from Firestore
class ProfileViewsService {
  static final _firestore = FirebaseFirestore.instance;

  /// Fetch view counts for a profile (one-time fetch)
  ///
  /// Returns map with keys:
  /// - 'total': Total all-time views
  /// - 'thisWeek': Views this week (placeholder - needs Cloud Function reset logic)
  /// - 'thisMonth': Views this month (placeholder - needs Cloud Function reset logic)
  ///
  /// Note: profileId should be in format "uuid_type" (e.g., "abc123_personal")
  /// to match Firestore document IDs created by FirestoreSyncService
  static Future<Map<String, int>> getViewCounts(String profileId) async {
    final fetchStartTime = DateTime.now();

    try {
      developer.log(
        '📊 Fetching view counts for profile: $profileId',
        name: 'ProfileViews.Fetch',
      );

      // Try exact ID first, then try without type suffix, then try with all type suffixes
      DocumentSnapshot? doc = await _firestore.collection('profiles').doc(profileId).get();

      if (!doc.exists) {
        developer.log(
          '⚠️ Profile not found with exact ID, trying alternative formats...',
          name: 'ProfileViews.Fetch',
        );

        // Extract UUID if format is "uuid_type"
        final uuidMatch = RegExp(r'^([0-9a-zA-Z]+)(?:_.*)?$').firstMatch(profileId);
        if (uuidMatch != null) {
          final baseId = uuidMatch.group(1)!;

          // Try all possible type suffixes
          for (final type in ['personal', 'professional', 'custom']) {
            final idWithType = '${baseId}_$type';
            doc = await _firestore.collection('profiles').doc(idWithType).get();

            if (doc.exists) {
              developer.log(
                '✅ Found profile with ID: $idWithType',
                name: 'ProfileViews.Fetch',
              );
              break;
            }
          }
        }
      }

      if (doc == null || !doc.exists) {
        developer.log(
          '⚠️ Profile not found in Firestore, returning zero counts',
          name: 'ProfileViews.Fetch',
        );
        return {'total': 0, 'thisWeek': 0, 'thisMonth': 0};
      }

      final data = doc.data() as Map<String, dynamic>;
      final counts = <String, int>{
        'total': (data['viewCount'] ?? 0) as int,
        // Note: thisWeek and thisMonth need Cloud Function scheduled job to reset
        // For now, we'll use the same total count
        'thisWeek': (data['viewCount'] ?? 0) as int,
        'thisMonth': (data['viewCount'] ?? 0) as int,
      };

      final fetchDuration = DateTime.now().difference(fetchStartTime).inMilliseconds;

      developer.log(
        '✅ View counts fetched successfully\n'
        '   • Total Views: ${counts['total']}\n'
        '   • This Week: ${counts['thisWeek']}\n'
        '   • This Month: ${counts['thisMonth']}\n'
        '   • Duration: ${fetchDuration}ms',
        name: 'ProfileViews.Fetch',
      );

      return counts;
    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(fetchStartTime).inMilliseconds;

      developer.log(
        '❌ Failed to fetch view counts\n'
        '   • Profile ID: $profileId\n'
        '   • Duration: ${errorDuration}ms\n'
        '   • Error: $e',
        name: 'ProfileViews.Fetch',
        error: e,
        stackTrace: stackTrace,
      );

      // Return zero counts on error
      return {'total': 0, 'thisWeek': 0, 'thisMonth': 0};
    }
  }

  /// Stream view counts (real-time updates)
  ///
  /// Use this for real-time analytics dashboards
  /// Updates automatically when view count changes in Firestore
  ///
  /// Note: profileId should be in format "uuid_type" (e.g., "abc123_personal")
  /// to match Firestore document IDs created by FirestoreSyncService
  static Stream<Map<String, int>> viewCountsStream(String profileId) async* {
    developer.log(
      '📡 Starting real-time view counts stream for: $profileId',
      name: 'ProfileViews.Stream',
    );

    // First, find the correct document ID
    String? correctDocId = profileId;

    // Try exact ID first
    var doc = await _firestore.collection('profiles').doc(profileId).get();

    if (!doc.exists) {
      developer.log(
        '⚠️ Profile not found with exact ID, trying alternative formats...',
        name: 'ProfileViews.Stream',
      );

      // Extract UUID if format is "uuid_type"
      final uuidMatch = RegExp(r'^([0-9a-zA-Z]+)(?:_.*)?$').firstMatch(profileId);
      if (uuidMatch != null) {
        final baseId = uuidMatch.group(1)!;

        // Try all possible type suffixes
        for (final type in ['personal', 'professional', 'custom']) {
          final idWithType = '${baseId}_$type';
          doc = await _firestore.collection('profiles').doc(idWithType).get();

          if (doc.exists) {
            correctDocId = idWithType;
            developer.log(
              '✅ Found profile with ID: $idWithType',
              name: 'ProfileViews.Stream',
            );
            break;
          }
        }
      }
    }

    // Now stream from the correct document
    yield* _firestore
        .collection('profiles')
        .doc(correctDocId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        developer.log(
          '⚠️ Profile not found in stream, returning zero counts',
          name: 'ProfileViews.Stream',
        );
        return {'total': 0, 'thisWeek': 0, 'thisMonth': 0};
      }

      final data = doc.data();
      final counts = <String, int>{
        'total': (data?['viewCount'] ?? 0) as int,
        // Note: thisWeek and thisMonth need Cloud Function scheduled job to reset
        'thisWeek': (data?['viewCount'] ?? 0) as int,
        'thisMonth': (data?['viewCount'] ?? 0) as int,
      };

      developer.log(
        '📊 View counts updated: ${counts['total']} total',
        name: 'ProfileViews.Stream',
      );

      return counts;
    });
  }

  /// Get last viewed timestamp
  static Future<DateTime?> getLastViewed(String profileId) async {
    try {
      final doc = await _firestore.collection('profiles').doc(profileId).get();

      if (!doc.exists) return null;

      final lastViewedAt = doc.data()?['lastViewedAt'] as Timestamp?;
      return lastViewedAt?.toDate();
    } catch (e) {
      developer.log(
        '❌ Failed to fetch last viewed timestamp',
        name: 'ProfileViews.LastViewed',
        error: e,
      );
      return null;
    }
  }

  /// Stream last viewed timestamp (real-time)
  static Stream<DateTime?> lastViewedStream(String profileId) {
    return _firestore
        .collection('profiles')
        .doc(profileId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;

      final lastViewedAt = doc.data()?['lastViewedAt'] as Timestamp?;
      return lastViewedAt?.toDate();
    });
  }
}
