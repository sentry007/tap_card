/// Batch Sync Helper Service
///
/// Provides utilities for bulk Firebase operations:
/// - Batch profile uploads
/// - Progress tracking
/// - Error handling per profile
/// - Sync reports generation
library;

import 'dart:developer' as developer;
import 'package:tap_card/core/models/profile_models.dart';
import 'package:tap_card/services/firestore_sync_service.dart';
import 'package:tap_card/services/sync_log_service.dart';

/// Result of a batch sync operation
class BatchSyncResult {
  final int total;
  final int successful;
  final int failed;
  final List<String> successfulIds;
  final Map<String, String> failures; // profileId -> error message
  final Duration duration;

  BatchSyncResult({
    required this.total,
    required this.successful,
    required this.failed,
    required this.successfulIds,
    required this.failures,
    required this.duration,
  });

  double get successRate => total > 0 ? (successful / total * 100) : 0;

  @override
  String toString() {
    return 'BatchSyncResult: $successful/$total successful (${successRate.toStringAsFixed(1)}%)';
  }

  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.writeln('📊 Batch Sync Results:');
    buffer.writeln('   • Total Profiles: $total');
    buffer.writeln('   • Successful: $successful');
    buffer.writeln('   • Failed: $failed');
    buffer.writeln('   • Success Rate: ${successRate.toStringAsFixed(1)}%');
    buffer.writeln('   • Duration: ${duration.inMilliseconds}ms');

    if (failures.isNotEmpty) {
      buffer.writeln('\n❌ Failures:');
      failures.forEach((id, error) {
        buffer.writeln('   • $id: $error');
      });
    }

    return buffer.toString();
  }
}

/// Callback for progress updates during batch operations
typedef BatchProgressCallback = void Function(int current, int total, String? currentProfileName);

/// Service for batch Firebase operations
class BatchSyncHelper {
  /// Sync multiple profiles to Firestore with progress tracking
  static Future<BatchSyncResult> syncProfiles(
    List<ProfileData> profiles, {
    BatchProgressCallback? onProgress,
    bool continueOnError = true,
    int delayBetweenSyncs = 100, // milliseconds
  }) async {
    final startTime = DateTime.now();

    developer.log(
      '📦 Starting batch sync of ${profiles.length} profiles...',
      name: 'BatchSync.Start',
    );

    final successfulIds = <String>[];
    final failures = <String, String>{};

    for (int i = 0; i < profiles.length; i++) {
      final profile = profiles[i];
      final syncStart = DateTime.now();

      // Notify progress
      onProgress?.call(i + 1, profiles.length, profile.name);

      developer.log(
        '🔄 Syncing profile ${i + 1}/${profiles.length}: ${profile.name}',
        name: 'BatchSync.Progress',
      );

      try {
        final syncResult = await FirestoreSyncService.syncProfileToFirestore(profile);
        final syncDuration = DateTime.now().difference(syncStart).inMilliseconds;
        final success = syncResult != null;

        if (success) {
          successfulIds.add(profile.id);

          // Log successful sync
          await SyncLogService.logSync(
            profileId: profile.id,
            profileName: profile.name,
            operation: 'batch_sync',
            success: true,
            duration: syncDuration,
          );

          developer.log(
            '✅ Synced: ${profile.name} (${syncDuration}ms)',
            name: 'BatchSync.Success',
          );
        } else {
          failures[profile.id] = 'Sync returned false';

          await SyncLogService.logSync(
            profileId: profile.id,
            profileName: profile.name,
            operation: 'batch_sync',
            success: false,
            errorMessage: 'Sync failed',
            duration: syncDuration,
          );

          developer.log(
            '❌ Failed: ${profile.name}',
            name: 'BatchSync.Failure',
          );

          if (!continueOnError) break;
        }
      } catch (e, stackTrace) {
        final syncDuration = DateTime.now().difference(syncStart).inMilliseconds;
        failures[profile.id] = e.toString();

        await SyncLogService.logSync(
          profileId: profile.id,
          profileName: profile.name,
          operation: 'batch_sync',
          success: false,
          errorMessage: e.toString(),
          duration: syncDuration,
        );

        developer.log(
          '❌ Error syncing ${profile.name}',
          name: 'BatchSync.Error',
          error: e,
          stackTrace: stackTrace,
        );

        if (!continueOnError) break;
      }

      // Delay between syncs to avoid rate limiting
      if (i < profiles.length - 1 && delayBetweenSyncs > 0) {
        await Future.delayed(Duration(milliseconds: delayBetweenSyncs));
      }
    }

    final duration = DateTime.now().difference(startTime);

    final result = BatchSyncResult(
      total: profiles.length,
      successful: successfulIds.length,
      failed: failures.length,
      successfulIds: successfulIds,
      failures: failures,
      duration: duration,
    );

    developer.log(
      result.toDetailedString(),
      name: 'BatchSync.Complete',
    );

    return result;
  }

  /// Retry failed syncs from a previous batch operation
  static Future<BatchSyncResult> retryFailedSyncs(
    List<ProfileData> allProfiles,
    BatchSyncResult previousResult, {
    BatchProgressCallback? onProgress,
  }) async {
    developer.log(
      '🔄 Retrying ${previousResult.failed} failed syncs...',
      name: 'BatchSync.Retry',
    );

    // Get profiles that failed
    final failedProfiles = allProfiles
        .where((profile) => previousResult.failures.containsKey(profile.id))
        .toList();

    if (failedProfiles.isEmpty) {
      developer.log(
        '✅ No failed profiles to retry',
        name: 'BatchSync.Retry',
      );

      return BatchSyncResult(
        total: 0,
        successful: 0,
        failed: 0,
        successfulIds: [],
        failures: {},
        duration: Duration.zero,
      );
    }

    return await syncProfiles(
      failedProfiles,
      onProgress: onProgress,
      continueOnError: true,
    );
  }

  /// Delete multiple profiles from Firestore
  static Future<BatchSyncResult> deleteProfiles(
    List<String> profileIds, {
    BatchProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();

    developer.log(
      '🗑️  Starting batch delete of ${profileIds.length} profiles...',
      name: 'BatchSync.Delete',
    );

    final successfulIds = <String>[];
    final failures = <String, String>{};

    for (int i = 0; i < profileIds.length; i++) {
      final profileId = profileIds[i];

      onProgress?.call(i + 1, profileIds.length, profileId);

      try {
        final success = await FirestoreSyncService.deleteProfileFromFirestore(profileId);

        if (success) {
          successfulIds.add(profileId);

          await SyncLogService.logSync(
            profileId: profileId,
            profileName: profileId,
            operation: 'batch_delete',
            success: true,
          );
        } else {
          failures[profileId] = 'Delete returned false';

          await SyncLogService.logSync(
            profileId: profileId,
            profileName: profileId,
            operation: 'batch_delete',
            success: false,
            errorMessage: 'Delete failed',
          );
        }
      } catch (e) {
        failures[profileId] = e.toString();

        await SyncLogService.logSync(
          profileId: profileId,
          profileName: profileId,
          operation: 'batch_delete',
          success: false,
          errorMessage: e.toString(),
        );
      }

      // Small delay to avoid rate limiting
      if (i < profileIds.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    final duration = DateTime.now().difference(startTime);

    final result = BatchSyncResult(
      total: profileIds.length,
      successful: successfulIds.length,
      failed: failures.length,
      successfulIds: successfulIds,
      failures: failures,
      duration: duration,
    );

    developer.log(
      result.toDetailedString(),
      name: 'BatchSync.Delete',
    );

    return result;
  }

  /// Generate a sync report as a formatted string
  static String generateReport(BatchSyncResult result) {
    return result.toDetailedString();
  }
}
