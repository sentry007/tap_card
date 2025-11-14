/// Centralized Logging Utility
///
/// Provides consistent logging across the app with support for
/// log levels and production vs development modes.
library;

import 'dart:developer' as developer;

/// Log levels for filtering output
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Centralized logger for consistent logging throughout the app
class Logger {
  /// Enable/disable logging (set to false in production)
  static bool enabled = true;

  /// Minimum log level to display
  static LogLevel minimumLevel = LogLevel.debug;

  /// Log a debug message
  ///
  /// Use for detailed debugging information
  static void debug(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      level: LogLevel.debug,
      emoji: '🔍',
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an info message
  ///
  /// Use for general informational messages
  static void info(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      level: LogLevel.info,
      emoji: 'ℹ️ ',
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning message
  ///
  /// Use for potentially problematic situations
  static void warning(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      level: LogLevel.warning,
      emoji: '⚠️ ',
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message
  ///
  /// Use for errors and exceptions
  static void error(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      level: LogLevel.error,
      emoji: '❌',
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a success message
  ///
  /// Use for successful operations
  static void success(
    String message, {
    String? name,
  }) {
    _log(
      message,
      level: LogLevel.info,
      emoji: '✅',
      name: name,
    );
  }

  /// Internal logging method
  static void _log(
    String message, {
    required LogLevel level,
    required String emoji,
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;
    if (level.index < minimumLevel.index) return;

    final formattedMessage = '$emoji $message';
    final logName = name ?? 'App';

    developer.log(
      formattedMessage,
      name: logName,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Disable all logging (for production)
  static void disableLogging() {
    enabled = false;
  }

  /// Enable all logging (for development)
  static void enableLogging() {
    enabled = true;
  }

  /// Set minimum log level
  static void setMinimumLevel(LogLevel level) {
    minimumLevel = level;
  }

  /// Configure logger for production
  ///
  /// Only shows warnings and errors
  static void configureForProduction() {
    enabled = true;
    minimumLevel = LogLevel.warning;
  }

  /// Configure logger for development
  ///
  /// Shows all log levels
  static void configureForDevelopment() {
    enabled = true;
    minimumLevel = LogLevel.debug;
  }
}
