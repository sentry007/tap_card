/// Sync Log Service
///
/// Tracks Firebase sync operations for debugging and audit:
/// - Records all sync attempts
/// - Stores success/failure status
/// - Maintains sync history
/// - Provides query and export capabilities
library;

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

/// Sync log entry model
class SyncLogEntry {
  final String id;
  final DateTime timestamp;
  final String profileId;
  final String profileName;
  final String operation; // 'create', 'update', 'delete'
  final bool success;
  final String? errorMessage;
  final int? duration; // milliseconds

  SyncLogEntry({
    required this.id,
    required this.timestamp,
    required this.profileId,
    required this.profileName,
    required this.operation,
    required this.success,
    this.errorMessage,
    this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'profileId': profileId,
      'profileName': profileName,
      'operation': operation,
      'success': success,
      'errorMessage': errorMessage,
      'duration': duration,
    };
  }

  factory SyncLogEntry.fromJson(Map<String, dynamic> json) {
    return SyncLogEntry(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      profileId: json['profileId'],
      profileName: json['profileName'],
      operation: json['operation'],
      success: json['success'],
      errorMessage: json['errorMessage'],
      duration: json['duration'],
    );
  }

  @override
  String toString() {
    return '${success ? "✅" : "❌"} [$operation] $profileName (${duration}ms)';
  }
}

/// Service for logging and tracking Firebase sync operations
class SyncLogService {
  static const String _storageKey = 'firebase_sync_logs';
  static const int _maxLogEntries = 100;

  static List<SyncLogEntry> _logs = [];
  static bool _isInitialized = false;

  /// Initialize the service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadLogs();
    _isInitialized = true;

    developer.log(
      '📋 Sync Log Service initialized with ${_logs.length} entries',
      name: 'SyncLog.Init',
    );
  }

  /// Log a sync operation
  static Future<void> logSync({
    required String profileId,
    required String profileName,
    required String operation,
    required bool success,
    String? errorMessage,
    int? duration,
  }) async {
    final entry = SyncLogEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      profileId: profileId,
      profileName: profileName,
      operation: operation,
      success: success,
      errorMessage: errorMessage,
      duration: duration,
    );

    _logs.insert(0, entry); // Add to beginning (most recent first)

    // Keep only last N entries
    if (_logs.length > _maxLogEntries) {
      _logs = _logs.sublist(0, _maxLogEntries);
    }

    await _saveLogs();

    developer.log(
      '📝 Logged sync: $entry',
      name: 'SyncLog.Log',
    );
  }

  /// Get all logs
  static List<SyncLogEntry> getAllLogs() {
    return List.unmodifiable(_logs);
  }

  /// Get logs for a specific profile
  static List<SyncLogEntry> getLogsForProfile(String profileId) {
    return _logs.where((log) => log.profileId == profileId).toList();
  }

  /// Get recent logs (last N entries)
  static List<SyncLogEntry> getRecentLogs(int count) {
    return _logs.take(count).toList();
  }

  /// Get failed syncs only
  static List<SyncLogEntry> getFailedSyncs() {
    return _logs.where((log) => !log.success).toList();
  }

  /// Get successful syncs only
  static List<SyncLogEntry> getSuccessfulSyncs() {
    return _logs.where((log) => log.success).toList();
  }

  /// Get sync statistics
  static Map<String, dynamic> getStatistics() {
    final total = _logs.length;
    final successful = _logs.where((log) => log.success).length;
    final failed = total - successful;
    final successRate = total > 0 ? (successful / total * 100).toStringAsFixed(1) : '0.0';

    final avgDuration = _logs.where((log) => log.duration != null).isNotEmpty
        ? _logs.where((log) => log.duration != null).map((log) => log.duration!).reduce((a, b) => a + b) / _logs.where((log) => log.duration != null).length
        : 0.0;

    return {
      'total': total,
      'successful': successful,
      'failed': failed,
      'successRate': '$successRate%',
      'avgDuration': '${avgDuration.toStringAsFixed(0)}ms',
      'lastSync': _logs.isNotEmpty ? _logs.first.timestamp : null,
    };
  }

  /// Clear all logs
  static Future<void> clearLogs() async {
    _logs.clear();
    await _saveLogs();

    developer.log(
      '🗑️  All sync logs cleared',
      name: 'SyncLog.Clear',
    );
  }

  /// Export logs as JSON string
  static String exportLogsAsJson() {
    final logsJson = _logs.map((log) => log.toJson()).toList();
    return jsonEncode(logsJson);
  }

  /// Export logs as CSV string
  static String exportLogsAsCsv() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Timestamp,Profile ID,Profile Name,Operation,Success,Error,Duration (ms)');

    // Data rows
    for (final log in _logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.profileId},"${log.profileName}",${log.operation},${log.success},"${log.errorMessage ?? ""}",${log.duration ?? ""}'
      );
    }

    return buffer.toString();
  }

  /// Load logs from storage
  static Future<void> _loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_storageKey);

      if (logsJson != null) {
        final List<dynamic> logsList = jsonDecode(logsJson);
        _logs = logsList.map((json) => SyncLogEntry.fromJson(json)).toList();

        developer.log(
          '📂 Loaded ${_logs.length} sync logs from storage',
          name: 'SyncLog.Load',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error loading sync logs',
        name: 'SyncLog.Load',
        error: e,
        stackTrace: stackTrace,
      );
      _logs = [];
    }
  }

  /// Save logs to storage
  static Future<void> _saveLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = jsonEncode(_logs.map((log) => log.toJson()).toList());
      await prefs.setString(_storageKey, logsJson);
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error saving sync logs',
        name: 'SyncLog.Save',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
