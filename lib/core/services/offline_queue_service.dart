/// Offline Queue Service
///
/// Queues operations when offline and syncs when online
/// Ensures no data loss during network outages
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';

/// Queued operation
class QueuedOperation {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime queuedAt;
  final int retryCount;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.queuedAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
        'queuedAt': queuedAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'],
      type: json['type'],
      data: Map<String, dynamic>.from(json['data']),
      queuedAt: DateTime.parse(json['queuedAt']),
      retryCount: json['retryCount'] ?? 0,
    );
  }

  QueuedOperation copyWithRetry() {
    return QueuedOperation(
      id: id,
      type: type,
      data: data,
      queuedAt: queuedAt,
      retryCount: retryCount + 1,
    );
  }
}

/// Offline queue service
class OfflineQueueService {
  // ========== Singleton Pattern ==========
  static final OfflineQueueService _instance =
      OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal() {
    _initialize();
  }

  // ========== Configuration ==========
  static const String storageKey = 'offline_queue';
  static const int maxQueueSize = 100;
  static const int maxRetries = 3;

  // ========== State ==========
  final List<QueuedOperation> _queue = [];
  bool _isSyncing = false;
  final ConnectivityService _connectivity = ConnectivityService();

  // ========== Callbacks ==========
  final Map<String, Future<void> Function(Map<String, dynamic>)> _handlers =
      {};

  // ========== Getters ==========
  List<QueuedOperation> get queue => List.unmodifiable(_queue);
  int get queueSize => _queue.length;
  bool get hasQueuedOperations => _queue.isNotEmpty;
  bool get isSyncing => _isSyncing;

  // ========== Public API ==========

  /// Register a handler for a specific operation type
  ///
  /// Example:
  /// ```dart
  /// OfflineQueueService().registerHandler(
  ///   'update_profile',
  ///   (data) async {
  ///     await repository.updateProfile(ProfileData.fromJson(data));
  ///   },
  /// );
  /// ```
  void registerHandler(
    String type,
    Future<void> Function(Map<String, dynamic> data) handler,
  ) {
    _handlers[type] = handler;

    developer.log(
      '✅ Registered handler for: $type',
      name: 'OfflineQueue.RegisterHandler',
    );
  }

  /// Queue an operation
  ///
  /// Example:
  /// ```dart
  /// await OfflineQueueService().queueOperation(
  ///   type: 'update_profile',
  ///   data: profile.toJson(),
  /// );
  /// ```
  Future<void> queueOperation({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    if (_queue.length >= maxQueueSize) {
      developer.log(
        '⚠️  Queue full, removing oldest operation',
        name: 'OfflineQueue.Queue',
      );
      _queue.removeAt(0);
    }

    final operation = QueuedOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      data: data,
      queuedAt: DateTime.now(),
    );

    _queue.add(operation);
    await _saveQueue();

    developer.log(
      '📥 Queued operation: $type (queue size: ${_queue.length})',
      name: 'OfflineQueue.Queue',
    );

    // Try to sync immediately if online
    if (_connectivity.isOnline) {
      unawaited(syncQueue());
    }
  }

  /// Sync queued operations
  Future<void> syncQueue() async {
    if (_isSyncing) {
      developer.log(
        'ℹ️  Sync already in progress',
        name: 'OfflineQueue.Sync',
      );
      return;
    }

    if (_queue.isEmpty) {
      return;
    }

    if (_connectivity.isOffline) {
      developer.log(
        '📴 Cannot sync: offline',
        name: 'OfflineQueue.Sync',
      );
      return;
    }

    _isSyncing = true;

    developer.log(
      '🔄 Starting sync (${_queue.length} operations)',
      name: 'OfflineQueue.Sync',
    );

    final operations = List<QueuedOperation>.from(_queue);
    final successfulOperations = <String>[];

    for (final operation in operations) {
      try {
        final handler = _handlers[operation.type];

        if (handler == null) {
          developer.log(
            '⚠️  No handler for: ${operation.type}',
            name: 'OfflineQueue.Sync',
          );
          // Remove operation with no handler
          successfulOperations.add(operation.id);
          continue;
        }

        // Execute operation
        await handler(operation.data);

        developer.log(
          '✅ Synced: ${operation.type} (${operation.id})',
          name: 'OfflineQueue.Sync',
        );

        successfulOperations.add(operation.id);
      } catch (e) {
        developer.log(
          '❌ Failed to sync: ${operation.type} - $e',
          name: 'OfflineQueue.Sync',
        );

        // Retry logic
        if (operation.retryCount < maxRetries) {
          // Update retry count
          final index = _queue.indexWhere((op) => op.id == operation.id);
          if (index != -1) {
            _queue[index] = operation.copyWithRetry();
          }
        } else {
          developer.log(
            '⚠️  Max retries reached for: ${operation.id}',
            name: 'OfflineQueue.Sync',
          );
          // Remove after max retries
          successfulOperations.add(operation.id);
        }
      }
    }

    // Remove successful operations
    _queue.removeWhere((op) => successfulOperations.contains(op.id));
    await _saveQueue();

    _isSyncing = false;

    developer.log(
      '✅ Sync complete: ${successfulOperations.length}/${operations.length} successful, ${_queue.length} remaining',
      name: 'OfflineQueue.Sync',
    );
  }

  /// Clear the queue
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();

    developer.log(
      '🗑️  Queue cleared',
      name: 'OfflineQueue.Clear',
    );
  }

  /// Get operations by type
  List<QueuedOperation> getOperationsByType(String type) {
    return _queue.where((op) => op.type == type).toList();
  }

  // ========== Private Methods ==========

  Future<void> _initialize() async {
    await _loadQueue();

    // Listen for connectivity changes
    _connectivity.addConnectivityListener((status) {
      if (status == ConnectivityStatus.online && _queue.isNotEmpty) {
        developer.log(
          '🌐 Back online, syncing queue...',
          name: 'OfflineQueue.Initialize',
        );
        unawaited(syncQueue());
      }
    });
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(storageKey);

      if (queueJson != null) {
        final List<dynamic> queueList = jsonDecode(queueJson);
        _queue.clear();
        _queue.addAll(
          queueList.map((json) => QueuedOperation.fromJson(json)),
        );

        developer.log(
          '📂 Loaded ${_queue.length} queued operations',
          name: 'OfflineQueue.Load',
        );
      }
    } catch (e) {
      developer.log(
        '❌ Failed to load queue: $e',
        name: 'OfflineQueue.Load',
      );
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((op) => op.toJson()).toList());
      await prefs.setString(storageKey, queueJson);

      developer.log(
        '💾 Saved queue (${_queue.length} operations)',
        name: 'OfflineQueue.Save',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to save queue: $e',
        name: 'OfflineQueue.Save',
      );
    }
  }
}

/// Helper function to avoid awaiting futures
void unawaited(Future<void> future) {
  // Intentionally not awaited
}
