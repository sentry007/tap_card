import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/unified_models.dart';
import 'firebase_config.dart';
import 'profile_data_service.dart';

/// Service for migrating data from local storage to Firebase
class FirebaseMigrationService {
  static bool _isMigrating = false;
  static bool _migrationCompleted = false;

  /// Check if migration is needed and available
  static Future<bool> isMigrationNeeded() async {
    if (!FirebaseConfig.isFirebaseEnabled || _migrationCompleted) {
      return false;
    }

    // // Check if there's local data to migrate
    // final hasLocalProfile = await ProfileDataService.hasProfile();
    // final tokenCount = await LocalTokenManager.getTokenCount();
    // return hasLocalProfile || tokenCount > 0;

    // For now, no migration needed (Firebase disabled)
    return false;
  }

  /// Perform complete data migration from local to Firebase
  static Future<MigrationResult> migrateAllData() async {
    if (_isMigrating) {
      return MigrationResult.error('Migration already in progress');
    }

    if (!FirebaseConfig.isFirebaseEnabled) {
      return MigrationResult.error('Firebase not configured');
    }

    _isMigrating = true;
    final startTime = DateTime.now();

    try {
      print('🚀 Starting Firebase migration...');

      final results = <String, dynamic>{
        'profiles': 0,
        'tokens': 0,
        'history': 0,
        'errors': <String>[],
      };

      // Step 1: Migrate user profile
      final profileResult = await _migrateProfile();
      results['profiles'] = profileResult['migrated'];
      if (profileResult['errors'].isNotEmpty) {
        results['errors'].addAll(profileResult['errors']);
      }

      // Step 2: Migrate share tokens
      final tokenResult = await _migrateTokens();
      results['tokens'] = tokenResult['migrated'];
      if (tokenResult['errors'].isNotEmpty) {
        results['errors'].addAll(tokenResult['errors']);
      }

      // Step 3: Migrate share history
      final historyResult = await _migrateHistory();
      results['history'] = historyResult['migrated'];
      if (historyResult['errors'].isNotEmpty) {
        results['errors'].addAll(historyResult['errors']);
      }

      final duration = DateTime.now().difference(startTime);

      if (results['errors'].isEmpty) {
        _migrationCompleted = true;
        await _markMigrationComplete();

        print('✅ Migration completed in ${duration.inMilliseconds}ms');
        return MigrationResult.success(results, duration);
      } else {
        print('⚠️ Migration completed with errors: ${results['errors']}');
        return MigrationResult.partialSuccess(results, duration);
      }
    } catch (e) {
      print('❌ Migration failed: $e');
      return MigrationResult.error(e.toString());
    } finally {
      _isMigrating = false;
    }
  }

  /// Migrate user profile data
  static Future<Map<String, dynamic>> _migrateProfile() async {
    try {
      final profile = await ProfileDataService.getCurrentProfile();
      if (profile == null) {
        return {'migrated': 0, 'errors': <String>[]};
      }

      // TODO: Migrate to Firestore
      // await FirebaseFirestore.instance
      //   .collection(FirebaseConfig.usersCollection)
      //   .doc(profile.id)
      //   .set(profile.toFirestoreJson());

      print('📤 Profile migration ready: ${profile.name}');

      return {'migrated': 1, 'errors': <String>[]};
    } catch (e) {
      return {'migrated': 0, 'errors': ['Profile migration failed: $e']};
    }
  }

  /// Migrate share tokens
  static Future<Map<String, dynamic>> _migrateTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokensJson = prefs.getString('share_tokens');

      if (tokensJson == null) {
        return {'migrated': 0, 'errors': <String>[]};
      }

      final tokens = Map<String, dynamic>.from(jsonDecode(tokensJson));
      int migrated = 0;
      final errors = <String>[];

      for (final entry in tokens.entries) {
        try {
          final tokenId = entry.key;
          final tokenData = entry.value as Map<String, dynamic>;

          // TODO: Migrate to Firestore
          // await FirebaseFirestore.instance
          //   .collection(FirebaseConfig.shareTokensCollection)
          //   .doc(tokenId)
          //   .set(tokenData);

          print('📤 Token migration ready: $tokenId');
          migrated++;
        } catch (e) {
          errors.add('Token ${entry.key} migration failed: $e');
        }
      }

      return {'migrated': migrated, 'errors': errors};
    } catch (e) {
      return {'migrated': 0, 'errors': ['Token migration failed: $e']};
    }
  }

  /// Migrate share history
  static Future<Map<String, dynamic>> _migrateHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('share_history');

      if (historyJson == null) {
        return {'migrated': 0, 'errors': <String>[]};
      }

      final history = List<dynamic>.from(jsonDecode(historyJson));
      int migrated = 0;
      final errors = <String>[];

      // Migrate in batches
      final batchSize = FirebaseConfig.migrationBatchSize;
      for (int i = 0; i < history.length; i += batchSize) {
        final batch = history.skip(i).take(batchSize).toList();

        for (final entry in batch) {
          try {
            // TODO: Migrate to Firestore
            // await FirebaseFirestore.instance
            //   .collection(FirebaseConfig.shareHistoryCollection)
            //   .add(entry);

            migrated++;
          } catch (e) {
            errors.add('History entry $i migration failed: $e');
          }
        }

        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('📤 History migration ready: $migrated entries');
      return {'migrated': migrated, 'errors': errors};
    } catch (e) {
      return {'migrated': 0, 'errors': ['History migration failed: $e']};
    }
  }

  /// Create backup of local data before migration
  static Future<bool> createLocalBackup() async {
    if (!FirebaseConfig.shouldKeepLocalBackup) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Backup profile
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        await prefs.setString('backup_profile_$timestamp', profileJson);
      }

      // Backup tokens
      final tokensJson = prefs.getString('share_tokens');
      if (tokensJson != null) {
        await prefs.setString('backup_tokens_$timestamp', tokensJson);
      }

      // Backup history
      final historyJson = prefs.getString('share_history');
      if (historyJson != null) {
        await prefs.setString('backup_history_$timestamp', historyJson);
      }

      print('💾 Local backup created: $timestamp');
      return true;
    } catch (e) {
      print('❌ Backup creation failed: $e');
      return false;
    }
  }

  /// Restore from local backup if migration fails
  static Future<bool> restoreFromBackup(int timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Restore profile
      final profileBackup = prefs.getString('backup_profile_$timestamp');
      if (profileBackup != null) {
        await prefs.setString('user_profile', profileBackup);
      }

      // Restore tokens
      final tokensBackup = prefs.getString('backup_tokens_$timestamp');
      if (tokensBackup != null) {
        await prefs.setString('share_tokens', tokensBackup);
      }

      // Restore history
      final historyBackup = prefs.getString('backup_history_$timestamp');
      if (historyBackup != null) {
        await prefs.setString('share_history', historyBackup);
      }

      print('🔄 Restored from backup: $timestamp');
      return true;
    } catch (e) {
      print('❌ Backup restore failed: $e');
      return false;
    }
  }

  /// Mark migration as completed
  static Future<void> _markMigrationComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firebase_migration_completed', true);
    await prefs.setString('migration_completed_at', DateTime.now().toIso8601String());
  }

  /// Check if migration was previously completed
  static Future<bool> wasMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('firebase_migration_completed') ?? false;
  }

  /// Get migration status and statistics
  static Future<Map<String, dynamic>> getMigrationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('firebase_migration_completed') ?? false;
    final completedAt = prefs.getString('migration_completed_at');

    return {
      'is_completed': completed,
      'completed_at': completedAt,
      'is_in_progress': _isMigrating,
      'firebase_enabled': FirebaseConfig.isFirebaseEnabled,
      'migration_needed': await isMigrationNeeded(),
    };
  }

  /// Clean up old backups (keep only last 3)
  static Future<void> cleanupOldBackups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('backup_')).toList();

      if (keys.length <= 3) return;

      // Sort by timestamp and remove oldest
      keys.sort();
      for (int i = 0; i < keys.length - 3; i++) {
        await prefs.remove(keys[i]);
      }

      print('🧹 Cleaned up ${keys.length - 3} old backups');
    } catch (e) {
      print('⚠️ Backup cleanup failed: $e');
    }
  }

  /// Test Firebase connectivity before migration
  static Future<bool> testFirebaseConnectivity() async {
    // return await FirebaseConfig.checkConnection();
    // For now, Firebase is disabled
    print('🔄 Firebase connectivity test - using offline mode');
    return false;
  }
}

/// Result class for migration operations
sealed class MigrationResult {
  const MigrationResult();

  factory MigrationResult.success(Map<String, dynamic> data, Duration duration) =
      MigrationSuccess;
  factory MigrationResult.partialSuccess(Map<String, dynamic> data, Duration duration) =
      MigrationPartialSuccess;
  factory MigrationResult.error(String message) = MigrationError;
}

class MigrationSuccess extends MigrationResult {
  final Map<String, dynamic> data;
  final Duration duration;

  const MigrationSuccess(this.data, this.duration);
}

class MigrationPartialSuccess extends MigrationResult {
  final Map<String, dynamic> data;
  final Duration duration;

  const MigrationPartialSuccess(this.data, this.duration);
}

class MigrationError extends MigrationResult {
  final String message;

  const MigrationError(this.message);
}