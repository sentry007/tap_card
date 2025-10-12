/// Profile Views Service
///
/// Tracks profile views across different platforms (web, app)
/// TODO: Integrate with Firebase Cloud Functions for web tracking
/// TODO: Implement Firestore increments for real-time view counts
library;

import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for tracking and retrieving profile view counts
class ProfileViewsService {
  static final ProfileViewsService _instance = ProfileViewsService._internal();
  factory ProfileViewsService() => _instance;
  ProfileViewsService._internal();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Increment profile views count
  ///
  /// TODO: Call this when:
  /// - Web: User opens tapcard.app/share/{uuid} (via Cloud Function)
  /// - App: User views received contact details from history
  ///
  /// @param profileId The unique profile ID
  /// @param source 'web' or 'app'
  static Future<void> incrementProfileViews({
    required String profileId,
    required String source,
  }) async {
    try {
      // Reference to profile views document
      final viewsRef = _firestore
          .collection('profileViews')
          .doc(profileId);

      // Use Firestore transaction to safely increment
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(viewsRef);

        if (!snapshot.exists) {
          // Create new document
          transaction.set(viewsRef, {
            'profileId': profileId,
            'totalViews': 1,
            'webViews': source == 'web' ? 1 : 0,
            'appViews': source == 'app' ? 1 : 0,
            'lastViewedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Increment existing document
          transaction.update(viewsRef, {
            'totalViews': FieldValue.increment(1),
            '${source}Views': FieldValue.increment(1),
            'lastViewedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      developer.log(
        '✅ Profile view incremented: $profileId ($source)',
        name: 'ProfileViews.Service'
      );
    } catch (e) {
      developer.log(
        '❌ Failed to increment profile views: $e',
        name: 'ProfileViews.Service',
        error: e
      );
    }
  }

  /// Get total profile views for a profile
  ///
  /// @param profileId The unique profile ID
  /// @returns Total view count, or 0 if no views recorded
  static Future<int> getProfileViews(String profileId) async {
    try {
      final doc = await _firestore
          .collection('profileViews')
          .doc(profileId)
          .get();

      if (!doc.exists) {
        return 0;
      }

      final data = doc.data();
      return (data?['totalViews'] as int?) ?? 0;
    } catch (e) {
      developer.log(
        '❌ Failed to get profile views: $e',
        name: 'ProfileViews.Service',
        error: e
      );
      return 0;
    }
  }

  /// Get detailed view statistics for a profile
  ///
  /// @param profileId The unique profile ID
  /// @returns Map with totalViews, webViews, appViews, lastViewedAt
  static Future<Map<String, dynamic>> getProfileViewStats(String profileId) async {
    try {
      final doc = await _firestore
          .collection('profileViews')
          .doc(profileId)
          .get();

      if (!doc.exists) {
        return {
          'totalViews': 0,
          'webViews': 0,
          'appViews': 0,
          'lastViewedAt': null,
        };
      }

      final data = doc.data();
      return {
        'totalViews': data?['totalViews'] ?? 0,
        'webViews': data?['webViews'] ?? 0,
        'appViews': data?['appViews'] ?? 0,
        'lastViewedAt': data?['lastViewedAt'],
      };
    } catch (e) {
      developer.log(
        '❌ Failed to get profile view stats: $e',
        name: 'ProfileViews.Service',
        error: e
      );
      return {
        'totalViews': 0,
        'webViews': 0,
        'appViews': 0,
        'lastViewedAt': null,
      };
    }
  }

  /// Listen to real-time updates for profile views
  ///
  /// @param profileId The unique profile ID
  /// @param onUpdate Callback function called when views update
  /// @returns StreamSubscription for cancellation
  static Stream<int> watchProfileViews(String profileId) {
    return _firestore
        .collection('profileViews')
        .doc(profileId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return 0;
          final data = snapshot.data();
          return (data?['totalViews'] as int?) ?? 0;
        });
  }

  /// Reset profile views (for testing/admin purposes)
  ///
  /// @param profileId The unique profile ID
  static Future<void> resetProfileViews(String profileId) async {
    try {
      await _firestore
          .collection('profileViews')
          .doc(profileId)
          .delete();

      developer.log(
        '🔄 Profile views reset: $profileId',
        name: 'ProfileViews.Service'
      );
    } catch (e) {
      developer.log(
        '❌ Failed to reset profile views: $e',
        name: 'ProfileViews.Service',
        error: e
      );
    }
  }
}
