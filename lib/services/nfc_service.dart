/// NFC Service for Contact Card Sharing
///
/// Optimized for writing data to NFC tags and phone-to-phone transmission.
/// Uses dual approach: native Android NFC + nfc_manager plugin for reliability.
///
/// **Features:**
/// - NTAG213/NTAG215 tag support
/// - Phone-to-phone NFC sharing (Android Beam)
/// - Multiple write strategies (NDEF, plain text, URL fallback)
/// - Comprehensive error handling and retry logic
/// - Performance tracking and logging
///
/// **NFC Write Strategies:**
/// 1. Primary: Native Android NFC (via MethodChannel)
///    - NDEF text record
///    - Plain text write
///    - URL data encoding
/// 2. Backup: nfc_manager plugin
///    - NDEF interface
///    - IsoDepPhone-to-phone interfaces (IsoGen, NfcA/B/F/V)
///    - NDEF formattable tags
///
/// **TODO:**
/// - Add read support for receiving contact cards
/// - Implement NDEF record parsing
/// - Add iOS support (CoreNFC)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../core/constants/app_constants.dart';

/// Singleton service managing all NFC operations
class NFCService {
  static bool _isAvailable = false;
  static bool _isSessionActive = false;
  static const MethodChannel _channel = MethodChannel('app.tapcard/nfc_write');
  static Completer<NFCResult>? _writeCompleter;
  static DateTime? _writeStartTime;

  /// Initialize NFC service
  static Future<bool> initialize() async {
    final startTime = DateTime.now();

    try {
      _isAvailable = await NfcManager.instance.isAvailable();
      final initDuration = DateTime.now().difference(startTime).inMilliseconds;

      if (_isAvailable) {
        developer.log(
          '✅ NFC initialized successfully in ${initDuration}ms',
          name: 'NFC.Initialize'
        );
      } else {
        developer.log(
          '❌ NFC not available on this device (${initDuration}ms)',
          name: 'NFC.Initialize'
        );
      }

      // Set up method call handler for callbacks from native
      _channel.setMethodCallHandler(_handleNativeCallback);

      return _isAvailable;
    } catch (e) {
      final initDuration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '❌ NFC initialization failed: $e (${initDuration}ms)',
        name: 'NFC.Initialize',
        error: e
      );
      return false;
    }
  }

  /// Handle callbacks from native Android code
  static Future<void> _handleNativeCallback(MethodCall call) async {
    developer.log(
      '📞 Received native callback: ${call.method}',
      name: 'NFC.Callback'
    );

    switch (call.method) {
      case 'onWriteSuccess':
        if (_writeCompleter != null && !_writeCompleter!.isCompleted && _writeStartTime != null) {
          final duration = DateTime.now().difference(_writeStartTime!).inMilliseconds;
          final bytesWritten = call.arguments as int? ?? 0;
          developer.log(
            '✅ Native write succeeded: $bytesWritten bytes in ${duration}ms',
            name: 'NFC.Callback'
          );
          _writeCompleter!.complete(NFCResult.success(duration, bytesWritten));
          _writeCompleter = null;
          _writeStartTime = null;
        }
        break;

      case 'onWriteError':
        if (_writeCompleter != null && !_writeCompleter!.isCompleted && _writeStartTime != null) {
          final duration = DateTime.now().difference(_writeStartTime!).inMilliseconds;
          final error = call.arguments as String? ?? 'Unknown error';
          developer.log(
            '❌ Native write failed: $error (${duration}ms)',
            name: 'NFC.Callback'
          );
          _writeCompleter!.complete(NFCResult.error(error, duration));
          _writeCompleter = null;
          _writeStartTime = null;
        }
        break;

      default:
        developer.log(
          '⚠️ Unknown callback method: ${call.method}',
          name: 'NFC.Callback'
        );
    }
  }

  /// Share profile data via NFC (optimized for instant sharing)
  ///
  /// High-level method for sharing profile data. Parses JSON payload
  /// and initiates NFC write operation.
  ///
  /// @param jsonPayload Pre-encoded JSON string with profile data
  /// @returns NFCResult with success/failure status and timing metrics
  static Future<NFCResult> shareProfileInstant(String jsonPayload) async {
    final startTime = DateTime.now();
    final payloadSizeBytes = utf8.encode(jsonPayload).length;

    developer.log(
      '📤 Starting profile share\n'
      '   • Payload size: $payloadSizeBytes bytes',
      name: 'NFC.Share'
    );

    try {
      final data = jsonDecode(jsonPayload);

      developer.log(
        '✅ JSON parsed successfully, initiating write operation',
        name: 'NFC.Share'
      );

      return await writeData(data);
    } catch (e) {
      final errorDuration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '❌ Failed to parse JSON payload: $e (${errorDuration}ms)',
        name: 'NFC.Share',
        error: e
      );
      return NFCResult.error('Invalid JSON payload', errorDuration);
    }
  }

  /// Legacy compatibility method for Map input
  static Future<bool> shareProfile(Map<String, dynamic> essentialData) async {
    final payload = {
      'app': 'tap_card',
      'v': '1.0',
      'd': essentialData,
      't': DateTime.now().millisecondsSinceEpoch,
    };
    final result = await writeData(payload);
    return result.isSuccess;
  }

  /// Write data to NFC tag using native Android foreground dispatch
  ///
  /// This method uses pure native Android NFC instead of nfc_manager session
  /// to avoid conflicts between Flutter and native NFC handling.
  ///
  /// **Process:**
  /// 1. Call native Android to enable foreground dispatch
  /// 2. Native waits for tag via onNewIntent()
  /// 3. Native writes NDEF message and sends callback
  /// 4. Return result based on native callback
  ///
  /// @param data Contact data as Map
  /// @param timeout Maximum wait time for NFC discovery (default: 10s)
  /// @returns NFCResult with operation status and metrics
  static Future<NFCResult> writeData(
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: NFCConstants.writeTimeoutSeconds),
  }) async {
    // Validate NFC availability
    if (!_isAvailable) {
      developer.log(
        '❌ NFC not available on device',
        name: 'NFC.Write'
      );
      return NFCResult.error('NFC not available. Please enable NFC in device settings.');
    }

    // Prevent concurrent sessions
    if (_isSessionActive) {
      developer.log(
        '⚠️  NFC session already active - ignoring duplicate request',
        name: 'NFC.Write'
      );
      return NFCResult.error('NFC session already in progress. Please wait or cancel the current operation.');
    }

    final startTime = DateTime.now();
    final jsonPayload = jsonEncode(data);
    final payloadSizeBytes = utf8.encode(jsonPayload).length;

    developer.log(
      '📤 Starting native NFC write\n'
      '   • Payload size: $payloadSizeBytes bytes\n'
      '   • Timeout: ${timeout.inSeconds}s',
      name: 'NFC.Write'
    );

    // Store completer and start time for callback handling
    _writeCompleter = Completer<NFCResult>();
    _writeStartTime = startTime;
    Timer? timeoutTimer;

    try {
      _isSessionActive = true;

      // Set up timeout
      timeoutTimer = Timer(timeout, () {
        if (_writeCompleter != null && !_writeCompleter!.isCompleted) {
          final timeoutDuration = DateTime.now().difference(startTime).inMilliseconds;
          developer.log(
            '⏰ NFC write timeout after ${timeoutDuration}ms',
            name: 'NFC.Write'
          );
          _writeCompleter!.complete(NFCResult.timeout(timeoutDuration));
          _writeCompleter = null;
          _writeStartTime = null;
          // Cancel native write mode
          _channel.invokeMethod('cancelWrite');
        }
      });

      // Call native Android to start foreground dispatch and wait for tag
      developer.log(
        '🔧 Enabling native Android foreground dispatch...',
        name: 'NFC.Write'
      );

      final success = await _channel.invokeMethod('writeNdefText', {
        'text': jsonPayload,
      });

      if (success == true) {
        developer.log(
          '✅ Native foreground dispatch enabled, waiting for tag...',
          name: 'NFC.Write'
        );

        // Wait for native callback or timeout
        // The native code will call back via method channel when write completes
        return await _writeCompleter!.future;
      } else {
        developer.log(
          '❌ Failed to enable native foreground dispatch',
          name: 'NFC.Write'
        );
        _writeCompleter = null;
        _writeStartTime = null;
        return NFCResult.error('Failed to start native NFC write');
      }

    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '❌ Native NFC write failed: $e (${errorDuration}ms)',
        name: 'NFC.Write',
        error: e,
        stackTrace: stackTrace
      );
      _writeCompleter = null;
      _writeStartTime = null;
      return NFCResult.error(e.toString(), errorDuration);
    } finally {
      timeoutTimer?.cancel();
      _isSessionActive = false;
    }
  }

  /// Internal method to write data to discovered NFC target
  ///
  /// Attempts multiple write strategies in order:
  /// 1. Native Android NFC (fastest, most reliable)
  /// 2. nfc_manager plugin (backup for unsupported scenarios)
  ///
  /// @param tag Discovered NFC tag
  /// @param jsonPayload JSON string to write
  /// @param payloadSizeBytes Payload size in bytes
  /// @param startTime Operation start time for metrics
  /// @returns NFCResult with write status
  static Future<NFCResult> _writeToTarget(
    NfcTag tag,
    String jsonPayload,
    int payloadSizeBytes,
    DateTime startTime,
  ) async {
    try {
      developer.log(
        '📋 NFC tag/device discovered - using native Android write',
        name: 'NFC.Write'
      );

      // Use native Android NFC platform channel (implemented in MainActivity.kt)
      final nativeResult = await _writeUsingNativeAndroid(jsonPayload, payloadSizeBytes, startTime);
      return nativeResult;

    } catch (e) {
      final errorTime = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '❌ Failed to write to target: $e (${errorTime}ms)',
        name: 'NFC.Write',
        error: e
      );
      return NFCResult.error(e.toString(), errorTime);
    }
  }

  /// Write using native Android NFC functionality
  static Future<NFCResult> _writeUsingNativeAndroid(
    String jsonPayload,
    int payloadSizeBytes,
    DateTime startTime,
  ) async {
    try {
      developer.log(
        '🔧 Using native Android NFC write',
        name: 'NFC.Write'
      );

      final nativeStartTime = DateTime.now();

      // Try writing as NDEF text record first
      try {
        final success = await _channel.invokeMethod('writeNdefText', {
          'text': jsonPayload,
        });

        final nativeTime = DateTime.now().difference(nativeStartTime).inMilliseconds;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;

        if (success == true) {
          developer.log(
            '✅ Successfully wrote ${payloadSizeBytes} bytes via native Android NDEF (native: ${nativeTime}ms, total: ${totalTime}ms)',
            name: 'NFC.Write'
          );
          return NFCResult.success(totalTime, payloadSizeBytes);
        }
      } catch (e) {
        developer.log(
          '⚠️ Native NDEF write failed: $e, trying plain text write',
          name: 'NFC.Write'
        );
      }

      // Fallback to plain text write
      try {
        final success = await _channel.invokeMethod('writeText', {
          'text': jsonPayload,
        });

        final nativeTime = DateTime.now().difference(nativeStartTime).inMilliseconds;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;

        if (success == true) {
          developer.log(
            '✅ Successfully wrote ${payloadSizeBytes} bytes via native Android text (native: ${nativeTime}ms, total: ${totalTime}ms)',
            name: 'NFC.Write'
          );
          return NFCResult.success(totalTime, payloadSizeBytes);
        }
      } catch (e) {
        developer.log(
          '⚠️ Native text write failed: $e, trying URL write',
          name: 'NFC.Write'
        );
      }

      // Final fallback: write as URL (some tags prefer this)
      try {
        final dataUrl = 'data:application/json;base64,${base64Encode(utf8.encode(jsonPayload))}';
        final success = await _channel.invokeMethod('writeUrl', {
          'url': dataUrl,
        });

        final nativeTime = DateTime.now().difference(nativeStartTime).inMilliseconds;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;

        if (success == true) {
          developer.log(
            '✅ Successfully wrote ${payloadSizeBytes} bytes via native Android URL (native: ${nativeTime}ms, total: ${totalTime}ms)',
            name: 'NFC.Write'
          );
          return NFCResult.success(totalTime, payloadSizeBytes);
        }
      } catch (e) {
        developer.log(
          '❌ All native Android write methods failed: $e',
          name: 'NFC.Write'
        );
      }

      return NFCResult.error('All native Android write methods failed');

    } catch (e) {
      developer.log(
        '❌ Native Android write exception: $e',
        name: 'NFC.Write',
        error: e
      );
      rethrow; // Let the caller handle this
    }
  }

  /// Stop active NFC session
  static Future<void> _stopSession() async {
    try {
      await NfcManager.instance.stopSession();
      _isSessionActive = false;
      developer.log('🛑 NFC session stopped', name: 'NFC.Stop');
    } catch (e) {
      developer.log(
        '⚠️  Error stopping NFC session: $e',
        name: 'NFC.Stop',
        error: e
      );
    }
  }

  /// Cancel active NFC session with optional error message
  static Future<void> cancelSession([String? errorMessage]) async {
    try {
      await NfcManager.instance.stopSession();
      _isSessionActive = false;
      developer.log(
        '🛑 NFC session cancelled${errorMessage != null ? ': $errorMessage' : ''}',
        name: 'NFC.Cancel'
      );
    } catch (e) {
      developer.log(
        '⚠️  Error cancelling NFC session: $e',
        name: 'NFC.Cancel',
        error: e
      );
    }
  }

  /// Process received NFC data (for compatibility)
  static Map<String, dynamic>? processReceivedData(String nfcData) {
    try {
      if (!nfcData.trim().startsWith('{')) return null;

      final jsonData = jsonDecode(nfcData) as Map<String, dynamic>;
      final appId = jsonData['app'] ?? jsonData['a'];
      if (appId != 'tap_card' && appId != 'tc') return null;

      final contactData = (jsonData['data'] ?? jsonData['d']) as Map<String, dynamic>?;
      final name = contactData?['name'] ?? contactData?['n'];
      if (contactData == null || name == null || name.toString().isEmpty) return null;

      developer.log('📖 Processed contact: $name', name: 'NFC.Process');
      return jsonData;

    } catch (e) {
      developer.log('❌ Failed to process NFC data: $e', name: 'NFC.Process', error: e);
      return null;
    }
  }

  /// Check if NFC is available
  static bool get isAvailable => _isAvailable;

  /// Check if an NFC session is currently active
  static bool get isSessionActive => _isSessionActive;

  /// Force cleanup of session state (for error recovery)
  static void forceCleanup() {
    _isSessionActive = false;
    _writeCompleter = null;
    _writeStartTime = null;
    developer.log('🧹 Forced cleanup of NFC session state', name: 'NFC.Cleanup');
  }
}

/// Result class for NFC operations
class NFCResult {
  final bool isSuccess;
  final String? error;
  final int durationMs;
  final int? dataSizeBytes;

  const NFCResult._({
    required this.isSuccess,
    this.error,
    required this.durationMs,
    this.dataSizeBytes,
  });

  factory NFCResult.success(int durationMs, int dataSizeBytes) {
    return NFCResult._(
      isSuccess: true,
      durationMs: durationMs,
      dataSizeBytes: dataSizeBytes,
    );
  }

  factory NFCResult.error(String error, [int durationMs = 0]) {
    return NFCResult._(
      isSuccess: false,
      error: error,
      durationMs: durationMs,
    );
  }

  factory NFCResult.timeout(int durationMs) {
    return NFCResult._(
      isSuccess: false,
      error: 'Timeout',
      durationMs: durationMs,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'NFCResult.success(${durationMs}ms, ${dataSizeBytes} bytes)';
    } else {
      return 'NFCResult.error("$error", ${durationMs}ms)';
    }
  }
}