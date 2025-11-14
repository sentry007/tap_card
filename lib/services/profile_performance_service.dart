/// Profile Performance Service
///
/// Provides analytics for view counts across all user profiles
/// Helps users understand which profile type performs best
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../core/models/profile_models.dart';

/// Statistics for a single profile's view performance
class ProfileViewStats {
  final String profileId;
  final ProfileType type;
  final String name;
  final int viewCount;
  final DateTime? lastViewedAt;
  final double percentageOfTotal;

  const ProfileViewStats({
    required this.profileId,
    required this.type,
    required this.name,
    required this.viewCount,
    required this.lastViewedAt,
    required this.percentageOfTotal,
  });

  ProfileViewStats copyWith({
    double? percentageOfTotal,
  }) {
    return ProfileViewStats(
      profileId: profileId,
      type: type,
      name: name,
      viewCount: viewCount,
      lastViewedAt: lastViewedAt,
      percentageOfTotal: percentageOfTotal ?? this.percentageOfTotal,
    );
  }
}

/// Service for fetching view performance across multiple profiles
class ProfilePerformanceService {
  static final _firestore = FirebaseFirestore.instance;

  /// Fetch view statistics for all user profiles
  ///
  /// Returns list of ProfileViewStats sorted by view count (highest first)
  /// Includes percentage breakdown relative to total views
  static Future<List<ProfileViewStats>> getAllProfileStats(
    List<ProfileData> profiles,
  ) async {
    final fetchStartTime = DateTime.now();

    try {
      developer.log(
        '📊 Fetching view stats for ${profiles.length} profiles',
        name: 'ProfilePerformance.Fetch',
      );

      if (profiles.isEmpty) {
        return [];
      }

      // Batch fetch all profile view counts
      final stats = <ProfileViewStats>[];
      for (final profile in profiles) {
        final docId = '${profile.id}_${profile.type.name}';
        final doc = await _firestore.collection('profiles').doc(docId).get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final viewCount = (data['viewCount'] ?? 0) as int;
          final lastViewedAt = (data['lastViewedAt'] as Timestamp?)?.toDate();

          stats.add(ProfileViewStats(
            profileId: profile.id,
            type: profile.type,
            name: profile.name,
            viewCount: viewCount,
            lastViewedAt: lastViewedAt,
            percentageOfTotal: 0.0, // Will calculate after fetching all
          ));
        } else {
          // Profile not yet synced to Firebase, show 0 views
          stats.add(ProfileViewStats(
            profileId: profile.id,
            type: profile.type,
            name: profile.name,
            viewCount: 0,
            lastViewedAt: null,
            percentageOfTotal: 0.0,
          ));
        }
      }

      // Calculate total views
      final totalViews = stats.fold<int>(0, (total, stat) => total + stat.viewCount);

      // Calculate percentages
      final statsWithPercentages = stats.map((stat) {
        final percentage = totalViews > 0
            ? (stat.viewCount / totalViews) * 100
            : 0.0;
        return stat.copyWith(percentageOfTotal: percentage);
      }).toList();

      // Sort by view count (highest first)
      statsWithPercentages.sort((a, b) => b.viewCount.compareTo(a.viewCount));

      final fetchDuration = DateTime.now().difference(fetchStartTime).inMilliseconds;

      developer.log(
        '✅ Profile stats fetched successfully\n'
        '   • Total Profiles: ${stats.length}\n'
        '   • Total Views: $totalViews\n'
        '   • Top Profile: ${statsWithPercentages.isNotEmpty ? statsWithPercentages.first.type.label : "None"}\n'
        '   • Duration: ${fetchDuration}ms',
        name: 'ProfilePerformance.Fetch',
      );

      return statsWithPercentages;
    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(fetchStartTime).inMilliseconds;

      developer.log(
        '❌ Failed to fetch profile stats\n'
        '   • Profiles Count: ${profiles.length}\n'
        '   • Duration: ${errorDuration}ms\n'
        '   • Error: $e',
        name: 'ProfilePerformance.Fetch',
        error: e,
        stackTrace: stackTrace,
      );

      // Return empty stats on error
      return profiles.map((profile) => ProfileViewStats(
        profileId: profile.id,
        type: profile.type,
        name: profile.name,
        viewCount: 0,
        lastViewedAt: null,
        percentageOfTotal: 0.0,
      )).toList();
    }
  }

  /// Get total view count across all profiles
  static Future<int> getTotalViewCount(List<ProfileData> profiles) async {
    try {
      final stats = await getAllProfileStats(profiles);
      return stats.fold<int>(0, (total, stat) => total + stat.viewCount);
    } catch (e) {
      developer.log(
        '❌ Failed to get total view count: $e',
        name: 'ProfilePerformance.TotalViews',
        error: e,
      );
      return 0;
    }
  }

  /// Get the profile with most views
  static Future<ProfileViewStats?> getTopProfile(List<ProfileData> profiles) async {
    try {
      final stats = await getAllProfileStats(profiles);
      if (stats.isEmpty) return null;
      return stats.first; // Already sorted by view count
    } catch (e) {
      developer.log(
        '❌ Failed to get top profile: $e',
        name: 'ProfilePerformance.TopProfile',
        error: e,
      );
      return null;
    }
  }
}
