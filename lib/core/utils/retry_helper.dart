/// Retry Helper
///
/// Implements automatic retry with exponential backoff
/// Handles transient failures gracefully
library;

import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;

/// Retry configuration
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool retryOnTimeout;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.retryOnTimeout = true,
  });

  /// Conservative retry (fewer attempts, longer delays)
  static const conservative = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
  );

  /// Aggressive retry (more attempts, shorter delays)
  static const aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 200),
    maxDelay: Duration(seconds: 60),
  );

  /// Network retry (optimized for network operations)
  static const network = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 15),
    retryOnTimeout: true,
  );
}

/// Retry result wrapper
class RetryResult<T> {
  final T? data;
  final int attempts;
  final bool succeeded;
  final Exception? lastError;

  RetryResult({
    this.data,
    required this.attempts,
    required this.succeeded,
    this.lastError,
  });
}

/// Retry helper with exponential backoff
class RetryHelper {
  /// Execute operation with automatic retry
  ///
  /// Example:
  /// ```dart
  /// final result = await RetryHelper.execute(
  ///   () => repository.fetchProfile(),
  ///   config: RetryConfig.network,
  ///   onRetry: (attempt, error) {
  ///     print('Retry attempt $attempt: $error');
  ///   },
  /// );
  /// ```
  static Future<T> execute<T>(
    Future<T> Function() operation, {
    RetryConfig config = const RetryConfig(),
    bool Function(Exception)? shouldRetry,
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < config.maxAttempts) {
      attempt++;

      try {
        developer.log(
          'Attempt $attempt/${config.maxAttempts}',
          name: 'RetryHelper.Execute',
        );

        final result = await operation();

        if (attempt > 1) {
          developer.log(
            '✅ Succeeded on attempt $attempt',
            name: 'RetryHelper.Execute',
          );
        }

        return result;
      } on TimeoutException catch (e) {
        lastError = e;

        if (!config.retryOnTimeout || attempt >= config.maxAttempts) {
          developer.log(
            '❌ Timeout after $attempt attempts',
            name: 'RetryHelper.Execute',
          );
          rethrow;
        }

        developer.log(
          '⏱️  Timeout on attempt $attempt, will retry',
          name: 'RetryHelper.Execute',
        );
      } catch (e) {
        if (e is! Exception) rethrow;

        lastError = e;

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(e)) {
          developer.log(
            '❌ Error is not retryable: $e',
            name: 'RetryHelper.Execute',
          );
          rethrow;
        }

        if (attempt >= config.maxAttempts) {
          developer.log(
            '❌ Failed after $attempt attempts: $e',
            name: 'RetryHelper.Execute',
          );
          rethrow;
        }

        developer.log(
          '⚠️  Attempt $attempt failed: $e',
          name: 'RetryHelper.Execute',
        );
      }

      // Call onRetry callback
      onRetry?.call(attempt, lastError);

      // Calculate delay with exponential backoff
      if (attempt < config.maxAttempts) {
        final delay = _calculateDelay(attempt, config);

        developer.log(
          '⏳ Waiting ${delay.inMilliseconds}ms before retry...',
          name: 'RetryHelper.Execute',
        );

        await Future.delayed(delay);
      }
    }

    // Should never reach here, but just in case
    throw lastError ?? Exception('Retry failed after $attempt attempts');
  }

  /// Execute with result wrapper (doesn't throw, returns result object)
  static Future<RetryResult<T>> executeWithResult<T>(
    Future<T> Function() operation, {
    RetryConfig config = const RetryConfig(),
    bool Function(Exception)? shouldRetry,
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    try {
      final data = await execute(
        operation,
        config: config,
        shouldRetry: shouldRetry,
        onRetry: onRetry,
      );

      return RetryResult(
        data: data,
        attempts: 1, // Successful on first try
        succeeded: true,
      );
    } catch (e) {
      if (e is! Exception) rethrow;

      return RetryResult<T>(
        data: null,
        attempts: config.maxAttempts,
        succeeded: false,
        lastError: e,
      );
    }
  }

  /// Calculate delay with exponential backoff and jitter
  static Duration _calculateDelay(int attempt, RetryConfig config) {
    // Exponential backoff: delay = initialDelay * (multiplier ^ (attempt - 1))
    final exponentialDelay = config.initialDelay.inMilliseconds *
        pow(config.backoffMultiplier, attempt - 1);

    // Add jitter (randomness) to prevent thundering herd
    final jitter = Random().nextDouble() * 0.3; // ±30% jitter
    final delayWithJitter = exponentialDelay * (1 + jitter - 0.15);

    // Cap at maxDelay
    final cappedDelay = min(delayWithJitter, config.maxDelay.inMilliseconds.toDouble());

    return Duration(milliseconds: cappedDelay.toInt());
  }

  /// Check if error is retryable (network errors, timeouts, server errors)
  static bool isRetryableError(Exception error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('host')) {
      return true;
    }

    // Timeout errors
    if (error is TimeoutException) {
      return true;
    }

    // Server errors (5xx)
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504')) {
      return true;
    }

    // Rate limit (429)
    if (errorString.contains('429') || errorString.contains('too many')) {
      return true;
    }

    // Default: don't retry
    return false;
  }
}

/// Extension for convenient retry
extension RetryExtension<T> on Future<T> {
  /// Retry this future with exponential backoff
  ///
  /// Example:
  /// ```dart
  /// final profile = await repository
  ///   .getProfile(id)
  ///   .withRetry(config: RetryConfig.network);
  /// ```
  Future<T> withRetry({
    RetryConfig config = const RetryConfig(),
    bool Function(Exception)? shouldRetry,
    void Function(int attempt, Exception error)? onRetry,
  }) {
    return RetryHelper.execute(
      () => this,
      config: config,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
  }
}
