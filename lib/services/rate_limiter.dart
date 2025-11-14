import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/security_constants.dart';

/// Rate limiter service to prevent API abuse
class RateLimiter {
  // Singleton pattern
  static final RateLimiter _instance = RateLimiter._internal();
  factory RateLimiter() => _instance;
  RateLimiter._internal();

  // Track requests per action
  final Map<String, List<DateTime>> _requestLog = {};
  final Map<String, DateTime> _lockoutUntil = {};

  /// Check if action is allowed (respects rate limits)
  bool isAllowed(String action) {
    final now = DateTime.now();

    // Check if action is locked out
    if (_lockoutUntil.containsKey(action)) {
      if (now.isBefore(_lockoutUntil[action]!)) {
        return false;
      } else {
        _lockoutUntil.remove(action);
      }
    }

    // Get action config
    final config = SecurityConstants.rateLimitConfig[action];
    if (config == null) {
      debugPrint('⚠️ No rate limit config for action: $action');
      return true; // Allow if no config found
    }

    // Initialize request log if needed
    _requestLog.putIfAbsent(action, () => []);

    // Clean old requests outside the time window
    final windowStart = now.subtract(config['window'] as Duration);
    _requestLog[action]!.removeWhere((time) => time.isBefore(windowStart));

    // Check if limit exceeded
    final requestCount = _requestLog[action]!.length;
    final maxRequests = config['maxRequests'] as int;

    if (requestCount >= maxRequests) {
      // Lock out the action
      _lockoutUntil[action] = now.add(config['lockoutDuration'] as Duration);
      debugPrint('🚫 Rate limit exceeded for $action. Locked out until ${_lockoutUntil[action]}');
      return false;
    }

    return true;
  }

  /// Record a request for the given action
  void recordRequest(String action) {
    _requestLog.putIfAbsent(action, () => []);
    _requestLog[action]!.add(DateTime.now());
  }

  /// Execute action with rate limiting
  Future<T?> executeWithLimit<T>({
    required String action,
    required Future<T> Function() task,
  }) async {
    if (!isAllowed(action)) {
      final lockoutUntil = _lockoutUntil[action];
      final remainingSeconds = lockoutUntil != null
          ? lockoutUntil.difference(DateTime.now()).inSeconds
          : 0;

      throw RateLimitException(
        'Rate limit exceeded for $action. Try again in $remainingSeconds seconds.',
        action: action,
        retryAfter: lockoutUntil,
      );
    }

    recordRequest(action);
    return await task();
  }

  /// Get remaining requests for an action
  int getRemainingRequests(String action) {
    final config = SecurityConstants.rateLimitConfig[action];
    if (config == null) return -1;

    final now = DateTime.now();
    final windowStart = now.subtract(config['window'] as Duration);

    _requestLog.putIfAbsent(action, () => []);
    _requestLog[action]!.removeWhere((time) => time.isBefore(windowStart));

    final maxRequests = config['maxRequests'] as int;
    final currentRequests = _requestLog[action]!.length;

    return maxRequests - currentRequests;
  }

  /// Check if action is currently locked out
  bool isLockedOut(String action) {
    if (!_lockoutUntil.containsKey(action)) return false;

    final now = DateTime.now();
    if (now.isBefore(_lockoutUntil[action]!)) {
      return true;
    } else {
      _lockoutUntil.remove(action);
      return false;
    }
  }

  /// Get time until lockout expires
  Duration? getLockoutRemaining(String action) {
    if (!_lockoutUntil.containsKey(action)) return null;

    final now = DateTime.now();
    final lockoutUntil = _lockoutUntil[action]!;

    if (now.isBefore(lockoutUntil)) {
      return lockoutUntil.difference(now);
    } else {
      _lockoutUntil.remove(action);
      return null;
    }
  }

  /// Clear all rate limit data (useful for testing)
  void clear() {
    _requestLog.clear();
    _lockoutUntil.clear();
  }

  /// Clear rate limit data for specific action
  void clearAction(String action) {
    _requestLog.remove(action);
    _lockoutUntil.remove(action);
  }
}

/// Exception thrown when rate limit is exceeded
class RateLimitException implements Exception {
  final String message;
  final String action;
  final DateTime? retryAfter;

  RateLimitException(
    this.message, {
    required this.action,
    this.retryAfter,
  });

  @override
  String toString() => 'RateLimitException: $message';
}
