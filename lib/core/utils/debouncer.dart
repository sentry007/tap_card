/// Debouncer Utility
///
/// Delays execution until user stops typing/interacting
/// Prevents excessive API calls from user input
library;

import 'dart:async';
import 'dart:developer' as developer;

/// Debouncer class
///
/// Delays function execution until after a specified duration
/// has passed since the last call
///
/// Example:
/// ```dart
/// final debouncer = Debouncer(duration: Duration(milliseconds: 500));
///
/// // In a text field onChange:
/// onChanged: (value) {
///   debouncer.run(() {
///     // This only runs 500ms after user stops typing
///     searchProfiles(value);
///   });
/// }
/// ```
class Debouncer {
  final Duration duration;
  Timer? _timer;
  int _callsAvoided = 0;

  Debouncer({
    this.duration = const Duration(milliseconds: 500),
  });

  /// Run the action after debounce duration
  void run(void Function() action) {
    // Cancel previous timer if still active
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _callsAvoided++;
    }

    // Start new timer
    _timer = Timer(duration, action);
  }

  /// Run async action after debounce duration
  void runAsync(Future<void> Function() action) {
    run(() => action());
  }

  /// Cancel any pending execution
  void cancel() {
    _timer?.cancel();
  }

  /// Get number of calls avoided by debouncing
  int get callsAvoided => _callsAvoided;

  /// Dispose the debouncer
  void dispose() {
    _timer?.cancel();

    if (_callsAvoided > 0) {
      developer.log(
        '📉 Debouncer disposed. Calls avoided: $_callsAvoided',
        name: 'Debouncer.Dispose',
      );
    }
  }
}

/// Throttler class
///
/// Limits function execution to once per specified duration
/// Executes immediately on first call, then enforces cooldown
///
/// Example:
/// ```dart
/// final throttler = Throttler(duration: Duration(seconds: 1));
///
/// // In a scroll listener:
/// onScroll: () {
///   throttler.run(() {
///     // This runs max once per second
///     loadMoreData();
///   });
/// }
/// ```
class Throttler {
  final Duration duration;
  DateTime? _lastExecutionTime;
  int _callsAvoided = 0;

  Throttler({
    this.duration = const Duration(seconds: 1),
  });

  /// Run the action if cooldown period has passed
  void run(void Function() action) {
    final now = DateTime.now();

    if (_lastExecutionTime == null ||
        now.difference(_lastExecutionTime!) > duration) {
      _lastExecutionTime = now;
      action();
    } else {
      _callsAvoided++;
    }
  }

  /// Run async action if cooldown period has passed
  void runAsync(Future<void> Function() action) {
    final now = DateTime.now();

    if (_lastExecutionTime == null ||
        now.difference(_lastExecutionTime!) > duration) {
      _lastExecutionTime = now;
      action();
    } else {
      _callsAvoided++;
    }
  }

  /// Get number of calls avoided by throttling
  int get callsAvoided => _callsAvoided;

  /// Dispose the throttler
  void dispose() {
    if (_callsAvoided > 0) {
      developer.log(
        '📉 Throttler disposed. Calls avoided: $_callsAvoided',
        name: 'Throttler.Dispose',
      );
    }
  }
}

/// Combined debounce and throttle
///
/// Provides both debouncing (delays until idle) and throttling (rate limiting)
/// Useful for search boxes that need both behaviors
class DebouncedThrottler {
  final Debouncer _debouncer;
  final Throttler _throttler;

  DebouncedThrottler({
    Duration debounceDuration = const Duration(milliseconds: 500),
    Duration throttleDuration = const Duration(seconds: 1),
  })  : _debouncer = Debouncer(duration: debounceDuration),
        _throttler = Throttler(duration: throttleDuration);

  /// Run with both debounce and throttle
  void run(void Function() action) {
    _throttler.run(() {
      _debouncer.run(action);
    });
  }

  /// Get total calls avoided
  int get callsAvoided => _debouncer.callsAvoided + _throttler.callsAvoided;

  /// Dispose both debouncer and throttler
  void dispose() {
    _debouncer.dispose();
    _throttler.dispose();
  }
}
