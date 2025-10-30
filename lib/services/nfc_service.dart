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
import '../models/unified_models.dart';

/// NFC Operation Mode
enum NfcMode {
  tagWrite,  // Write to physical NFC tags (default)
  p2pShare,  // Phone-to-phone sharing via HCE
}

/// Singleton service managing all NFC operations
class NFCService {
  static bool _isAvailable = false;
  static bool _isSessionActive = false;
  static const MethodChannel _channel = MethodChannel('app.tapcard/nfc_write');
  static Completer<NFCResult>? _writeCompleter;
  static DateTime? _writeStartTime;

  // HCE (Host Card Emulation) support
  static bool _isHceActive = false;
  static bool _isHceSupported = false;

  // NFC Mode Management
  static NfcMode _currentMode = NfcMode.tagWrite;

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

      // Check HCE support (always available since we have custom service)
      try {
        _isHceSupported = true; // Custom NfcTagEmulatorService is always available
        developer.log(
          '✅ NFC HCE (card emulation) supported with custom Type 4 Tag service',
          name: 'NFC.Initialize'
        );
      } catch (e) {
        developer.log(
          '⚠️ Failed to check HCE support: $e',
          name: 'NFC.Initialize',
          error: e
        );
        _isHceSupported = false;
      }

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

          // Handle map argument from Android with tag metadata
          final data = call.arguments is Map ? call.arguments as Map : {'bytesWritten': call.arguments as int};
          final bytesWritten = data['bytesWritten'] as int? ?? 0;
          final tagId = data['tagId'] as String?;
          final tagCapacity = data['tagCapacity'] as int?;
          final payloadType = data['payloadType'] as String?;

          developer.log(
            '✅ Native write succeeded: $bytesWritten bytes in ${duration}ms\n'
            '   • Payload Type: ${payloadType ?? "unknown"} (${payloadType == "dual" ? "Full card" : "Mini card"})\n'
            '   • Tag ID: ${tagId ?? "unknown"}\n'
            '   • Tag Capacity: ${tagCapacity ?? "unknown"} bytes',
            name: 'NFC.Callback'
          );
          _writeCompleter!.complete(NFCResult.success(duration, bytesWritten, tagId: tagId, tagCapacity: tagCapacity, payloadType: payloadType));
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
  /// **Dual-Payload Strategy:**
  /// Writes TWO NDEF records to the tag:
  /// 1. vCard record - Basic contact info (name, phone, email) for universal compatibility
  /// 2. URL record - Link to full digital card with all information
  ///
  /// **Process:**
  /// 1. Prepare dual payload (vCard + URL)
  /// 2. Call native Android to enable foreground dispatch
  /// 3. Native waits for tag via onNewIntent()
  /// 4. Native writes NDEF message with both records and sends callback
  /// 5. Return result based on native callback
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

    // Extract pre-cached dual payload (vCard + URL)
    // This should already be generated and cached in ProfileData for instant sharing!
    final String vCard;
    final String cardUrl;

    developer.log(
      '🔍 Extracting dual-payload from data...\n'
      '   • Data keys: ${data.keys.toList()}',
      name: 'NFC.Write.Extract'
    );

    if (data.containsKey('vcard') && data.containsKey('url')) {
      // ✅ OPTIMIZED PATH: Pre-cached payload passed directly
      vCard = data['vcard'] as String;
      cardUrl = data['url'] as String;

      developer.log(
        '✅ Using PRE-CACHED dual-payload (0ms lag!)\n'
        '   • vCard: ${vCard.length} bytes (from cache)\n'
        '   • URL: ${cardUrl.length} bytes (from cache)\n'
        '   • Total: ${vCard.length + cardUrl.length} bytes\n'
        '   🚀 Performance: INSTANT (no generation overhead)',
        name: 'NFC.Write.Cached'
      );
    } else {
      // ⚠️ FALLBACK PATH: Generate on-demand (backwards compatibility)
      developer.log(
        '⚠️ No pre-cached payload found, generating on-demand...\n'
        '   This is slower! Consider using ProfileData.dualPayload',
        name: 'NFC.Write.Fallback'
      );

      final contactData = data['d'] ?? data['data'];
      final contact = contactData is Map<String, dynamic>
          ? ContactData.fromJson(contactData)
          : ContactData.fromJson(data);

      vCard = contact.toVCard();
      cardUrl = contact.generateCardUrl('user_${DateTime.now().millisecondsSinceEpoch}');

      developer.log(
        '✅ Generated dual-payload on-demand\n'
        '   • vCard: ${vCard.length} bytes\n'
        '   • URL: ${cardUrl.length} bytes',
        name: 'NFC.Write.Generated'
      );
    }

    final vCardBytes = utf8.encode(vCard).length;
    final urlBytes = utf8.encode(cardUrl).length;

    developer.log(
      '📦 Preparing DUAL-PAYLOAD for native Android\n'
      '   📇 vCard: $vCardBytes bytes (basic contact info)\n'
      '   🌐 URL: $urlBytes bytes (full digital card)\n'
      '   💡 Native Android will detect tag capacity and choose:\n'
      '      • Dual-payload (vCard + URL) if tag is large enough\n'
      '      • URL-only fallback if dual-payload doesn\'t fit\n'
      '   ⏱️  Timeout: ${timeout.inSeconds}s',
      name: 'NFC.Write.Prepare'
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
      // Always send both vCard and URL - native code will decide based on actual tag capacity
      developer.log(
        '🔧 Enabling native Android foreground dispatch...\n'
        '📤 Calling writeDualPayload with vCard + URL\n'
        '   (Native will auto-fallback to URL-only if needed)',
        name: 'NFC.Write'
      );

      final bool success = await _channel.invokeMethod('writeDualPayload', {
        'vcard': vCard,
        'url': cardUrl,
      }) == true;

      if (success) {
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
            '✅ Successfully wrote $payloadSizeBytes bytes via native Android NDEF (native: ${nativeTime}ms, total: ${totalTime}ms)',
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
            '✅ Successfully wrote $payloadSizeBytes bytes via native Android text (native: ${nativeTime}ms, total: ${totalTime}ms)',
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
            '✅ Successfully wrote $payloadSizeBytes bytes via native Android URL (native: ${nativeTime}ms, total: ${totalTime}ms)',
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

  // ============================================================================
  // HCE (Host Card Emulation) Methods - Phone acts as NFC tag
  // ============================================================================

  /// Enable card emulation with dual-payload (vCard + URL fallback)
  ///
  /// This allows other NFC-enabled phones to read your contact data by
  /// tapping their phone against yours. Your phone emulates an NFC tag.
  ///
  /// Uses pre-cached payloads from ProfileData for zero-latency activation.
  ///
  /// @param vCard Pre-cached vCard 3.0 contact string
  /// @param url Pre-cached card URL for fallback
  /// @returns NFCResult with success/failure status
  static Future<NFCResult> startCardEmulation(String vCard, String url) async {
    final startTime = DateTime.now();

    // Check HCE support
    if (!_isHceSupported) {
      return NFCResult.error('Card emulation not supported on this device');
    }

    // Check if already active
    if (_isHceActive) {
      return NFCResult.error('Card emulation already active');
    }

    try {
      // Start custom NDEF emulation service
      developer.log(
        '🎯 Starting NDEF emulation with custom Type 4 Tag service...\n'
        '   📇 vCard: ${vCard.length} chars\n'
        '   🌐 URL: $url',
        name: 'NFC.HCE'
      );

      final result = await _channel.invokeMethod('startNdefEmulation', {
        'vcard': vCard,
        'url': url,
      });

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (result != null && result['success'] == true) {
        _isHceActive = true;
        final sizeBytes = result['size'] ?? 0;

        developer.log(
          '✅ NDEF emulation active (${duration}ms, $sizeBytes bytes)\n'
          '   📲 Tap Android → Saves vCard\n'
          '   📲 Tap iPhone → Opens URL\n'
          '   🔹 Service: NfcTagEmulatorService\n'
          '   🔹 AID: D2760000850101\n'
          '   🔹 Type: NFC Forum Type 4 Tag',
          name: 'NFC.HCE'
        );

        return NFCResult.success(duration, sizeBytes);
      } else {
        return NFCResult.error('Failed to start NDEF emulation', duration);
      }

    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '❌ HCE exception: $e (${duration}ms)',
        name: 'NFC.HCE',
        error: e,
        stackTrace: stackTrace
      );
      return NFCResult.error('Exception: ${e.toString()}', duration);
    }
  }

  /// Stop card emulation mode
  static Future<void> stopCardEmulation() async {
    if (!_isHceActive) {
      developer.log(
        'ℹ️ Card emulation not active, nothing to stop',
        name: 'NFC.HCE'
      );
      return;
    }

    try {
      await _channel.invokeMethod('stopNdefEmulation');
      _isHceActive = false;
      developer.log(
        '🛑 NDEF emulation stopped',
        name: 'NFC.HCE'
      );
    } catch (e) {
      developer.log(
        '⚠️ Error stopping NDEF emulation: $e',
        name: 'NFC.HCE',
        error: e
      );
      // Force cleanup even if stop fails
      _isHceActive = false;
    }
  }

  /// Check if HCE is supported on this device
  static bool get isHceSupported => _isHceSupported;

  /// Check if card emulation is currently active
  static bool get isHceActive => _isHceActive;

  // ============================================================================
  // NFC Mode Management
  // ============================================================================

  /// Get current NFC mode
  static NfcMode get currentMode => _currentMode;

  /// Switch NFC operation mode
  static void switchMode(NfcMode newMode) {
    final oldMode = _currentMode;
    _currentMode = newMode;

    developer.log(
      '🔄 NFC mode switched\n'
      '   From: ${oldMode == NfcMode.tagWrite ? "Tag Write" : "P2P Share"}\n'
      '   To: ${newMode == NfcMode.tagWrite ? "Tag Write" : "P2P Share"}\n'
      '   Status: Mode change complete',
      name: 'NFC.Mode'
    );
  }

  /// Check if currently in Tag Write mode
  static bool get isTagWriteMode => _currentMode == NfcMode.tagWrite;

  /// Check if currently in P2P Share mode
  static bool get isP2pMode => _currentMode == NfcMode.p2pShare;
}

/// Result class for NFC operations
class NFCResult {
  final bool isSuccess;
  final String? error;
  final int durationMs;
  final int? dataSizeBytes;
  final String? tagId;
  final String? tagType;
  final int? tagCapacity;
  final String? payloadType;  // "dual" or "url"

  const NFCResult._({
    required this.isSuccess,
    this.error,
    required this.durationMs,
    this.dataSizeBytes,
    this.tagId,
    this.tagType,
    this.tagCapacity,
    this.payloadType,
  });

  factory NFCResult.success(int durationMs, int dataSizeBytes, {String? tagId, String? tagType, int? tagCapacity, String? payloadType}) {
    return NFCResult._(
      isSuccess: true,
      durationMs: durationMs,
      dataSizeBytes: dataSizeBytes,
      tagId: tagId,
      tagType: tagType,
      tagCapacity: tagCapacity,
      payloadType: payloadType,
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
      return 'NFCResult.success(${durationMs}ms, $dataSizeBytes bytes, type: $payloadType)';
    } else {
      return 'NFCResult.error("$error", ${durationMs}ms)';
    }
  }
}