/// Error Tracking Service
///
/// Centralized error tracking and logging
/// Provides user-friendly error messages
/// Integrates with Sentry for production monitoring (optional)
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  fatal,
}

/// User-friendly error message
class UserFriendlyError {
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? action;

  UserFriendlyError({
    required this.title,
    required this.message,
    this.actionText,
    this.action,
  });
}

/// Error tracking service
class ErrorTrackingService {
  // ========== Singleton Pattern ==========
  static final ErrorTrackingService _instance =
      ErrorTrackingService._internal();
  factory ErrorTrackingService() => _instance;
  ErrorTrackingService._internal();

  // ========== Configuration ==========
  static bool enableSentry = false; // Set to true when Sentry is configured
  static bool logToConsole = true;

  // ========== Error Tracking ==========
  final List<Map<String, dynamic>> _errorLog = [];
  final Map<String, int> _errorCounts = {};

  // ========== Public API ==========

  /// Track an error
  void trackError(
    dynamic error, {
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
    Map<String, dynamic>? context,
  }) {
    final errorEntry = {
      'error': error.toString(),
      'stackTrace': stackTrace?.toString(),
      'severity': severity.name,
      'timestamp': DateTime.now().toIso8601String(),
      'context': context,
    };

    _errorLog.add(errorEntry);
    _errorCounts[error.runtimeType.toString()] =
        (_errorCounts[error.runtimeType.toString()] ?? 0) + 1;

    // Log to console
    if (logToConsole) {
      _logToConsole(error, stackTrace, severity);
    }

    // Send to Sentry (if enabled)
    if (enableSentry) {
      _sendToSentry(error, stackTrace, severity, context);
    }
  }

  /// Get user-friendly error message
  UserFriendlyError getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return UserFriendlyError(
        title: 'Connection Problem',
        message:
            'Unable to connect to the server. Please check your internet connection and try again.',
        actionText: 'Retry',
      );
    }

    // Timeout errors
    if (error is TimeoutException || errorString.contains('timeout')) {
      return UserFriendlyError(
        title: 'Request Timeout',
        message:
            'The request took too long. Please check your connection and try again.',
        actionText: 'Retry',
      );
    }

    // Offline errors
    if (errorString.contains('offline')) {
      return UserFriendlyError(
        title: 'No Internet Connection',
        message:
            'You appear to be offline. Please check your internet connection.',
        actionText: 'Settings',
      );
    }

    // Authentication errors
    if (errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('401')) {
      return UserFriendlyError(
        title: 'Authentication Required',
        message: 'Please sign in to continue.',
        actionText: 'Sign In',
      );
    }

    // Permission errors
    if (errorString.contains('permission') ||
        errorString.contains('forbidden') ||
        errorString.contains('403')) {
      return UserFriendlyError(
        title: 'Access Denied',
        message: "You don't have permission to perform this action.",
      );
    }

    // Not found errors
    if (errorString.contains('not found') || errorString.contains('404')) {
      return UserFriendlyError(
        title: 'Not Found',
        message: 'The requested item could not be found.',
      );
    }

    // Rate limit errors
    if (errorString.contains('429') ||
        errorString.contains('too many') ||
        errorString.contains('rate limit')) {
      return UserFriendlyError(
        title: 'Too Many Requests',
        message: 'You\'re making requests too quickly. Please wait a moment and try again.',
      );
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('server error')) {
      return UserFriendlyError(
        title: 'Server Error',
        message:
            'Our servers are experiencing issues. Please try again later.',
        actionText: 'Retry',
      );
    }

    // Validation errors
    if (errorString.contains('validation') ||
        errorString.contains('invalid')) {
      return UserFriendlyError(
        title: 'Invalid Input',
        message: 'Please check your input and try again.',
      );
    }

    // Storage errors
    if (errorString.contains('storage') || errorString.contains('disk')) {
      return UserFriendlyError(
        title: 'Storage Error',
        message: 'Unable to save data. Please check your device storage.',
      );
    }

    // Default error
    return UserFriendlyError(
      title: 'Something Went Wrong',
      message:
          'An unexpected error occurred. Please try again or contact support if the problem persists.',
      actionText: 'Retry',
    );
  }

  /// Get error statistics
  Map<String, dynamic> getStats() {
    return {
      'totalErrors': _errorLog.length,
      'errorsByType': _errorCounts,
      'recentErrors': _errorLog.reversed.take(10).toList(),
    };
  }

  /// Print error statistics
  void printStats() {
    final stats = getStats();

    developer.log(
      '📊 Error Statistics:\n'
      '   • Total Errors: ${stats['totalErrors']}\n'
      '   • Error Types: ${_errorCounts.length}',
      name: 'ErrorTracking.Stats',
    );

    if (_errorCounts.isNotEmpty) {
      developer.log(
        '\n📈 Top Errors:',
        name: 'ErrorTracking.Stats',
      );

      final sortedErrors = _errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedErrors.take(5)) {
        developer.log(
          '   • ${entry.key}: ${entry.value}',
          name: 'ErrorTracking.Stats',
        );
      }
    }
  }

  /// Clear error log
  void clear() {
    _errorLog.clear();
    _errorCounts.clear();

    developer.log(
      '🗑️  Error log cleared',
      name: 'ErrorTracking.Clear',
    );
  }

  // ========== Private Methods ==========

  void _logToConsole(
    dynamic error,
    StackTrace? stackTrace,
    ErrorSeverity severity,
  ) {
    final icon = _getSeverityIcon(severity);

    developer.log(
      '$icon [${severity.name.toUpperCase()}] $error',
      name: 'ErrorTracking',
      error: error,
      stackTrace: stackTrace,
      level: _getSeverityLevel(severity),
    );
  }

  void _sendToSentry(
    dynamic error,
    StackTrace? stackTrace,
    ErrorSeverity severity,
    Map<String, dynamic>? context,
  ) {
    // TODO: Integrate with Sentry
    // Example:
    // await Sentry.captureException(
    //   error,
    //   stackTrace: stackTrace,
    //   hint: Hint.withMap(context ?? {}),
    // );

    developer.log(
      '📤 Would send to Sentry: $error',
      name: 'ErrorTracking.Sentry',
    );
  }

  String _getSeverityIcon(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return 'ℹ️';
      case ErrorSeverity.warning:
        return '⚠️';
      case ErrorSeverity.error:
        return '❌';
      case ErrorSeverity.fatal:
        return '💀';
    }
  }

  int _getSeverityLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return 800; // INFO
      case ErrorSeverity.warning:
        return 900; // WARNING
      case ErrorSeverity.error:
        return 1000; // SEVERE
      case ErrorSeverity.fatal:
        return 1200; // SHOUT
    }
  }
}

/// Global error handler
void handleError(
  dynamic error, {
  StackTrace? stackTrace,
  ErrorSeverity severity = ErrorSeverity.error,
  Map<String, dynamic>? context,
}) {
  ErrorTrackingService().trackError(
    error,
    stackTrace: stackTrace,
    severity: severity,
    context: context,
  );
}
