/// Connectivity Service
///
/// Monitors network connectivity and provides real-time status
/// Detects online/offline states for reliability features
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Network connectivity status
enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

/// Connectivity service for monitoring network state
class ConnectivityService extends ChangeNotifier {
  // ========== Singleton Pattern ==========
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal() {
    _initialize();
  }

  // ========== State ==========
  ConnectivityStatus _status = ConnectivityStatus.unknown;
  Timer? _periodicCheck;
  final List<Function(ConnectivityStatus)> _listeners = [];

  // ========== Configuration ==========
  static const Duration checkInterval = Duration(seconds: 10);
  static const Duration initialCheckDelay = Duration(seconds: 2);
  static const List<String> testHosts = [
    'www.google.com',
    'www.cloudflare.com',
    '1.1.1.1',
  ];

  // ========== Getters ==========
  ConnectivityStatus get status => _status;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isOffline => _status == ConnectivityStatus.offline;
  bool get isUnknown => _status == ConnectivityStatus.unknown;

  // ========== Public API ==========

  /// Start monitoring connectivity
  void startMonitoring() {
    // Initial check after short delay
    Future.delayed(initialCheckDelay, checkConnectivity);

    // Periodic checks
    _periodicCheck?.cancel();
    _periodicCheck = Timer.periodic(checkInterval, (_) {
      checkConnectivity();
    });

    developer.log(
      '🔍 Started connectivity monitoring (every ${checkInterval.inSeconds}s)',
      name: 'ConnectivityService.Start',
    );
  }

  /// Stop monitoring connectivity
  void stopMonitoring() {
    _periodicCheck?.cancel();
    _periodicCheck = null;

    developer.log(
      '⏸️  Stopped connectivity monitoring',
      name: 'ConnectivityService.Stop',
    );
  }

  /// Check connectivity manually
  Future<ConnectivityStatus> checkConnectivity() async {
    final newStatus = await _testConnectivity();

    if (newStatus != _status) {
      final previousStatus = _status;
      _status = newStatus;

      developer.log(
        '🔄 Connectivity changed: ${previousStatus.name} → ${newStatus.name}',
        name: 'ConnectivityService.Change',
      );

      // Notify listeners
      notifyListeners();
      for (final listener in _listeners) {
        listener(newStatus);
      }
    }

    return _status;
  }

  /// Add listener for connectivity changes
  void addConnectivityListener(Function(ConnectivityStatus) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeConnectivityListener(Function(ConnectivityStatus) listener) {
    _listeners.remove(listener);
  }

  /// Wait for online status
  ///
  /// Useful for queueing operations until network is available
  Future<void> waitForOnline({Duration? timeout}) async {
    if (isOnline) return;

    final completer = Completer<void>();
    late Function(ConnectivityStatus) listener;

    listener = (status) {
      if (status == ConnectivityStatus.online) {
        removeConnectivityListener(listener);
        completer.complete();
      }
    };

    addConnectivityListener(listener);

    if (timeout != null) {
      return completer.future.timeout(
        timeout,
        onTimeout: () {
          removeConnectivityListener(listener);
          throw TimeoutException('Timeout waiting for online status');
        },
      );
    }

    return completer.future;
  }

  // ========== Private Methods ==========

  void _initialize() {
    // Start monitoring immediately
    startMonitoring();
  }

  /// Test actual network connectivity
  Future<ConnectivityStatus> _testConnectivity() async {
    try {
      // Try multiple hosts for reliability
      for (final host in testHosts) {
        try {
          final result = await InternetAddress.lookup(host)
              .timeout(const Duration(seconds: 3));

          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            return ConnectivityStatus.online;
          }
        } catch (e) {
          // Try next host
          continue;
        }
      }

      // All hosts failed
      return ConnectivityStatus.offline;
    } catch (e) {
      developer.log(
        '⚠️  Connectivity check failed: $e',
        name: 'ConnectivityService.Check',
      );
      return ConnectivityStatus.offline;
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    _listeners.clear();
    super.dispose();
  }
}

/// Exception thrown when attempting operation while offline
class OfflineException implements Exception {
  final String message;

  OfflineException([this.message = 'Device is offline']);

  @override
  String toString() => 'OfflineException: $message';
}
