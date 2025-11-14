/// Tests for RetryHelper
///
/// Demonstrates retry logic testing patterns
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_card/core/utils/retry_helper.dart';

void main() {
  group('RetryHelper', () {
    test('execute succeeds on first attempt', () async {
      var attempts = 0;

      final result = await RetryHelper.execute(
        () async {
          attempts++;
          return 'success';
        },
        config: const RetryConfig(maxAttempts: 3),
      );

      expect(result, 'success');
      expect(attempts, 1);
    });

    test('execute retries on failure and eventually succeeds', () async {
      var attempts = 0;

      final result = await RetryHelper.execute(
        () async {
          attempts++;
          if (attempts < 3) {
            throw Exception('Temporary failure');
          }
          return 'success';
        },
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 10),
        ),
      );

      expect(result, 'success');
      expect(attempts, 3);
    });

    test('execute throws after max attempts', () async {
      var attempts = 0;

      expect(
        () => RetryHelper.execute(
          () async {
            attempts++;
            throw Exception('Persistent failure');
          },
          config: const RetryConfig(
            maxAttempts: 2,
            initialDelay: Duration(milliseconds: 10),
          ),
        ),
        throwsException,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(attempts, 2);
    });

    test('execute calls onRetry callback', () async {
      var retryCallbacks = 0;
      var lastAttempt = 0;

      try {
        await RetryHelper.execute(
          () async {
            throw Exception('Test error');
          },
          config: const RetryConfig(
            maxAttempts: 3,
            initialDelay: Duration(milliseconds: 10),
          ),
          onRetry: (attempt, error) {
            retryCallbacks++;
            lastAttempt = attempt;
          },
        );
      } catch (e) {
        // Expected to throw
      }

      expect(retryCallbacks, 2); // Called on attempts 1 and 2 (not on final failure)
      expect(lastAttempt, 2);
    });

    test('execute respects shouldRetry function', () async {
      var attempts = 0;

      expect(
        () => RetryHelper.execute(
          () async {
            attempts++;
            throw Exception('Non-retryable');
          },
          config: const RetryConfig(maxAttempts: 3),
          shouldRetry: (error) => false, // Never retry
        ),
        throwsException,
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(attempts, 1); // Should not retry
    });

    test('isRetryableError identifies network errors', () {
      expect(
        RetryHelper.isRetryableError(Exception('Socket exception')),
        true,
      );
      expect(
        RetryHelper.isRetryableError(Exception('Network error')),
        true,
      );
      expect(
        RetryHelper.isRetryableError(Exception('Connection timeout')),
        true,
      );
    });

    test('isRetryableError identifies server errors', () {
      expect(RetryHelper.isRetryableError(Exception('500 server error')), true);
      expect(RetryHelper.isRetryableError(Exception('503 unavailable')), true);
    });

    test('isRetryableError rejects client errors', () {
      expect(RetryHelper.isRetryableError(Exception('400 bad request')), false);
      expect(RetryHelper.isRetryableError(Exception('Invalid input')), false);
    });

    test('executeWithResult returns success result', () async {
      final result = await RetryHelper.executeWithResult(
        () async => 'success',
        config: const RetryConfig(maxAttempts: 3),
      );

      expect(result.succeeded, true);
      expect(result.data, 'success');
      expect(result.lastError, isNull);
    });

    test('executeWithResult returns failure result', () async {
      final result = await RetryHelper.executeWithResult<String>(
        () async => throw Exception('Test error'),
        config: const RetryConfig(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 10),
        ),
      );

      expect(result.succeeded, false);
      expect(result.data, isNull);
      expect(result.lastError, isNotNull);
      expect(result.attempts, 2);
    });

    test('RetryConfig.conservative has correct defaults', () {
      expect(RetryConfig.conservative.maxAttempts, 2);
      expect(RetryConfig.conservative.initialDelay, const Duration(seconds: 1));
    });

    test('RetryConfig.aggressive has correct defaults', () {
      expect(RetryConfig.aggressive.maxAttempts, 5);
      expect(RetryConfig.aggressive.initialDelay, const Duration(milliseconds: 200));
    });

    test('RetryConfig.network has correct defaults', () {
      expect(RetryConfig.network.maxAttempts, 3);
      expect(RetryConfig.network.retryOnTimeout, true);
    });
  });

  group('RetryExtension', () {
    test('withRetry extension works correctly', () async {
      var attempts = 0;

      final result = await Future(() async {
        attempts++;
        if (attempts < 2) {
          throw Exception('Temporary failure');
        }
        return 'success';
      }).withRetry(
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 10),
        ),
      );

      expect(result, 'success');
      expect(attempts, 2);
    });
  });
}
