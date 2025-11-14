/// Performance Monitor
///
/// Tracks and reports performance metrics:
/// - Query execution times
/// - Network call counts
/// - Cache hit rates
/// - Memory usage
library;

import 'dart:async';
import 'dart:developer' as developer;

/// Performance metric entry
class PerformanceMetric {
  final String operation;
  final int durationMs;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceMetric({
    required this.operation,
    required this.durationMs,
    required this.timestamp,
    this.metadata,
  });

  @override
  String toString() {
    return '$operation: ${durationMs}ms';
  }
}

/// Performance monitor singleton
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  // ========== Configuration ==========

  /// Enable/disable performance monitoring
  static bool enabled = true;

  /// Maximum metrics to keep in memory
  static const int maxMetrics = 1000;

  /// Slow query threshold (ms)
  static const int slowQueryThreshold = 500;

  // ========== Metrics Storage ==========

  final List<PerformanceMetric> _metrics = [];
  final Map<String, List<int>> _operationTimes = {};

  int _totalQueries = 0;
  int _slowQueries = 0;
  int _networkCalls = 0;

  // ========== Public API ==========

  /// Measure execution time of an operation
  ///
  /// Example:
  /// ```dart
  /// final result = await PerformanceMonitor().measure(
  ///   'fetchProfiles',
  ///   () => repository.getAllProfiles(),
  /// );
  /// ```
  Future<T> measure<T>(
    String operation,
    Future<T> Function() task, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!enabled) {
      return await task();
    }

    final startTime = DateTime.now();
    final stopwatch = Stopwatch()..start();

    try {
      final result = await task();
      stopwatch.stop();

      final durationMs = stopwatch.elapsedMilliseconds;

      _recordMetric(
        operation: operation,
        durationMs: durationMs,
        timestamp: startTime,
        metadata: metadata,
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      _recordMetric(
        operation: '$operation (failed)',
        durationMs: stopwatch.elapsedMilliseconds,
        timestamp: startTime,
        metadata: {
          ...?metadata,
          'error': e.toString(),
        },
      );

      rethrow;
    }
  }

  /// Measure synchronous operation
  T measureSync<T>(
    String operation,
    T Function() task, {
    Map<String, dynamic>? metadata,
  }) {
    if (!enabled) {
      return task();
    }

    final startTime = DateTime.now();
    final stopwatch = Stopwatch()..start();

    try {
      final result = task();
      stopwatch.stop();

      _recordMetric(
        operation: operation,
        durationMs: stopwatch.elapsedMilliseconds,
        timestamp: startTime,
        metadata: metadata,
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      _recordMetric(
        operation: '$operation (failed)',
        durationMs: stopwatch.elapsedMilliseconds,
        timestamp: startTime,
        metadata: {
          ...?metadata,
          'error': e.toString(),
        },
      );

      rethrow;
    }
  }

  /// Record a network call
  void recordNetworkCall(String endpoint, {int? durationMs}) {
    _networkCalls++;

    if (durationMs != null) {
      _recordMetric(
        operation: 'network_$endpoint',
        durationMs: durationMs,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getStats() {
    if (_metrics.isEmpty) {
      return {
        'totalOperations': 0,
        'totalQueries': 0,
        'slowQueries': 0,
        'networkCalls': 0,
        'averageQueryTime': 0,
      };
    }

    final allTimes = _metrics.map((m) => m.durationMs).toList();
    final avgTime = allTimes.reduce((a, b) => a + b) / allTimes.length;

    return {
      'totalOperations': _metrics.length,
      'totalQueries': _totalQueries,
      'slowQueries': _slowQueries,
      'slowQueryRate': _totalQueries > 0
          ? (_slowQueries / _totalQueries * 100).toStringAsFixed(1)
          : '0.0',
      'networkCalls': _networkCalls,
      'averageQueryTime': avgTime.toStringAsFixed(1),
      'operationBreakdown': _getOperationBreakdown(),
    };
  }

  /// Print performance summary
  void printSummary() {
    final stats = getStats();

    developer.log(
      '⚡ Performance Summary:\n'
      '   • Total Operations: ${stats['totalOperations']}\n'
      '   • Total Queries: ${stats['totalQueries']}\n'
      '   • Slow Queries: ${stats['slowQueries']} (${stats['slowQueryRate']}%)\n'
      '   • Network Calls: ${stats['networkCalls']}\n'
      '   • Avg Query Time: ${stats['averageQueryTime']}ms',
      name: 'PerformanceMonitor.Summary',
    );

    _printOperationBreakdown();
  }

  /// Get slowest operations
  List<PerformanceMetric> getSlowestOperations({int limit = 10}) {
    final sorted = List<PerformanceMetric>.from(_metrics)
      ..sort((a, b) => b.durationMs.compareTo(a.durationMs));

    return sorted.take(limit).toList();
  }

  /// Clear all metrics
  void clear() {
    _metrics.clear();
    _operationTimes.clear();
    _totalQueries = 0;
    _slowQueries = 0;
    _networkCalls = 0;

    developer.log(
      '🗑️  Performance metrics cleared',
      name: 'PerformanceMonitor.Clear',
    );
  }

  /// Export metrics as JSON
  List<Map<String, dynamic>> exportMetrics() {
    return _metrics
        .map((m) => {
              'operation': m.operation,
              'durationMs': m.durationMs,
              'timestamp': m.timestamp.toIso8601String(),
              'metadata': m.metadata,
            })
        .toList();
  }

  // ========== Private Helpers ==========

  void _recordMetric({
    required String operation,
    required int durationMs,
    required DateTime timestamp,
    Map<String, dynamic>? metadata,
  }) {
    final metric = PerformanceMetric(
      operation: operation,
      durationMs: durationMs,
      timestamp: timestamp,
      metadata: metadata,
    );

    // Add to list
    _metrics.add(metric);

    // Evict old metrics if needed
    if (_metrics.length > maxMetrics) {
      _metrics.removeAt(0);
    }

    // Track by operation type
    _operationTimes.putIfAbsent(operation, () => []);
    _operationTimes[operation]!.add(durationMs);

    // Track query stats
    if (operation.contains('fetch') ||
        operation.contains('get') ||
        operation.contains('query')) {
      _totalQueries++;

      if (durationMs > slowQueryThreshold) {
        _slowQueries++;

        developer.log(
          '🐌 Slow query detected: $operation (${durationMs}ms)',
          name: 'PerformanceMonitor.SlowQuery',
        );
      }
    }
  }

  Map<String, Map<String, dynamic>> _getOperationBreakdown() {
    final breakdown = <String, Map<String, dynamic>>{};

    for (final entry in _operationTimes.entries) {
      final times = entry.value;
      if (times.isEmpty) continue;

      final avg = times.reduce((a, b) => a + b) / times.length;
      final min = times.reduce((a, b) => a < b ? a : b);
      final max = times.reduce((a, b) => a > b ? a : b);

      breakdown[entry.key] = {
        'count': times.length,
        'avg': avg.toStringAsFixed(1),
        'min': min,
        'max': max,
      };
    }

    return breakdown;
  }

  void _printOperationBreakdown() {
    final breakdown = _getOperationBreakdown();

    if (breakdown.isEmpty) return;

    developer.log(
      '\n📊 Operation Breakdown:',
      name: 'PerformanceMonitor.Breakdown',
    );

    for (final entry in breakdown.entries) {
      final stats = entry.value;
      developer.log(
        '   • ${entry.key}:\n'
        '     - Count: ${stats['count']}\n'
        '     - Avg: ${stats['avg']}ms\n'
        '     - Range: ${stats['min']}-${stats['max']}ms',
        name: 'PerformanceMonitor.Breakdown',
      );
    }
  }
}

/// Extension for convenient performance monitoring
extension PerformanceMonitorExtension on Future {
  /// Measure this future with performance monitoring
  ///
  /// Example:
  /// ```dart
  /// final profiles = await repository
  ///   .getAllProfiles()
  ///   .withPerformanceTracking('getAllProfiles');
  /// ```
  Future<T> withPerformanceTracking<T>(String operation) async {
    return PerformanceMonitor().measure(operation, () async => await this as T);
  }
}
