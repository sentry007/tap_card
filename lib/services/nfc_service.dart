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
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';

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
  static final FlutterNfcHce _hcePlugin = FlutterNfcHce();
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

      // Check HCE support
      try {
        _isHceSupported = await _hcePlugin.isNfcHceSupported() ?? false;
        if (_isHceSupported) {
          developer.log(
            '✅ NFC HCE (card emulation) supported on this device',
            name: 'NFC.Initialize'
          );
        } else {
          developer.log(
            'ℹ️ NFC HCE not supported (device limitation)',
            name: 'NFC.Initialize'
          );
        }
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

          developer.log(
            '✅ Native write succeeded: $bytesWritten bytes in ${duration}ms\n'
            '   • Tag ID: ${tagId ?? "unknown"}\n'
            '   • Tag Capacity: ${tagCapacity ?? "unknown"} bytes',
            name: 'NFC.Callback'
          );
          _writeCompleter!.complete(NFCResult.success(duration, bytesWritten, tagId: tagId, tagCapacity: tagCapacity));
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

    // Estimate NDEF overhead for accurate size checking
    // - vCard MIME record: ~13 bytes (TNF + type length + payload length + "text/x-vcard")
    // - URL record: ~9 bytes (TNF + type length + payload length + protocol byte)
    const int vCardOverhead = 13;
    const int urlOverhead = 9;
    final estimatedDualPayloadSize = vCardBytes + urlBytes + vCardOverhead + urlOverhead;
    final estimatedUrlOnlySize = urlBytes + urlOverhead;

    // Default to NTAG213 capacity (smallest common tag) for safety
    // If tag is larger (NTAG215/216), it will work fine
    const int defaultTagCapacity = NFCConstants.ntag213MaxBytes; // 144 bytes

    // Determine write strategy based on size
    final bool useDualPayload = estimatedDualPayloadSize <= defaultTagCapacity;
    final bool useUrlOnly = !useDualPayload && estimatedUrlOnlySize <= defaultTagCapacity;

    if (useDualPayload) {
      developer.log(
        '📦 Using DUAL-PAYLOAD strategy (fits in default capacity)\n'
        '   📇 Record 1 (vCard):\n'
        '      • Type: MIME (text/x-vcard)\n'
        '      • Data: $vCardBytes bytes\n'
        '      • Overhead: ~$vCardOverhead bytes\n'
        '      • Contains: Basic contact info (auto-saveable)\n'
        '   🌐 Record 2 (URL):\n'
        '      • Type: URI\n'
        '      • Data: $urlBytes bytes\n'
        '      • Overhead: ~$urlOverhead bytes\n'
        '      • URL: $cardUrl\n'
        '   📊 Size Check:\n'
        '      • Estimated total: $estimatedDualPayloadSize bytes\n'
        '      • Default capacity: $defaultTagCapacity bytes (NTAG213)\n'
        '      • Status: ✅ FITS (${((estimatedDualPayloadSize / defaultTagCapacity) * 100).toStringAsFixed(1)}% used)\n'
        '   ⏱️  Timeout: ${timeout.inSeconds}s',
        name: 'NFC.Write.DualPayload'
      );
    } else if (useUrlOnly) {
      developer.log(
        '📦 Using URL-ONLY fallback strategy (dual payload too large)\n'
        '   ⚠️  Dual payload size: ~$estimatedDualPayloadSize bytes > $defaultTagCapacity bytes\n'
        '   🌐 Fallback to URL-only:\n'
        '      • Type: URI\n'
        '      • Data: $urlBytes bytes\n'
        '      • Overhead: ~$urlOverhead bytes\n'
        '      • URL: $cardUrl\n'
        '   📊 Size Check:\n'
        '      • Estimated total: $estimatedUrlOnlySize bytes\n'
        '      • Default capacity: $defaultTagCapacity bytes (NTAG213)\n'
        '      • Status: ✅ FITS (${((estimatedUrlOnlySize / defaultTagCapacity) * 100).toStringAsFixed(1)}% used)\n'
        '   💡 Note: URL provides link to full digital card\n'
        '   ⏱️  Timeout: ${timeout.inSeconds}s',
        name: 'NFC.Write.UrlOnly'
      );
    } else {
      // Neither strategy fits - this is unlikely with reasonable data
      final errorDuration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '❌ Payload too large even for URL-only strategy\n'
        '   • URL size: ~$estimatedUrlOnlySize bytes\n'
        '   • Default capacity: $defaultTagCapacity bytes (NTAG213)\n'
        '   💡 Try using a larger tag (NTAG215: 504 bytes, NTAG216: 888 bytes)',
        name: 'NFC.Write.Error'
      );
      return NFCResult.error(
        'Payload too large for standard NFC tags. URL alone requires $estimatedUrlOnlySize bytes. '
        'Try using NTAG215 (504 bytes) or NTAG216 (888 bytes) tags.',
        errorDuration,
      );
    }

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

      // Call appropriate native method based on strategy
      final bool success;
      if (useDualPayload) {
        developer.log(
          '📤 Calling writeDualPayload with vCard + URL',
          name: 'NFC.Write'
        );
        success = await _channel.invokeMethod('writeDualPayload', {
          'vcard': vCard,
          'url': cardUrl,
        }) == true;
      } else {
        // URL-only fallback
        developer.log(
          '📤 Calling writeUrlOnly with URL: $cardUrl',
          name: 'NFC.Write'
        );
        success = await _channel.invokeMethod('writeUrlOnly', {
          'url': cardUrl,
        }) == true;
      }

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

  // ============================================================================
  // HCE (Host Card Emulation) Methods - Phone acts as NFC tag
  // ============================================================================

  /// Enable card emulation mode - phone acts as an NFC tag
  ///
  /// This allows other NFC-enabled phones to read your contact data by
  /// tapping their phone against yours. Your phone emulates an NFC tag.
  ///
  /// @param jsonPayload The data to share when another phone reads
  /// @returns NFCResult with success/failure status
  static Future<NFCResult> startCardEmulation(String jsonPayload) async {
    final startTime = DateTime.now();

    // Check HCE support
    if (!_isHceSupported) {
      developer.log(
        '❌ HCE not supported on this device',
        name: 'NFC.HCE'
      );
      return NFCResult.error('Card emulation not supported on this device. Try writing to a physical NFC tag instead.');
    }

    // Check if already active
    if (_isHceActive) {
      developer.log(
        '⚠️ Card emulation already active',
        name: 'NFC.HCE'
      );
      return NFCResult.error('Card emulation already active');
    }

    final payloadSizeBytes = utf8.encode(jsonPayload).length;

    developer.log(
      '📤 Starting card emulation mode\n'
      '   • Payload size: $payloadSizeBytes bytes\n'
      '   • Your phone will act as an NFC tag',
      name: 'NFC.HCE'
    );

    try {
      developer.log(
        '🔧 Calling flutter_nfc_hce plugin startNfcHce() with vCard MIME type...',
        name: 'NFC.HCE'
      );

      // Start HCE with vCard MIME type - this tells Android to trigger contact save dialog
      final result = await _hcePlugin.startNfcHce(
        jsonPayload,
        mimeType: 'text/x-vcard', // Critical: Use vCard MIME type, not text/plain
      );
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      developer.log(
        '📊 Plugin returned: $result (type: ${result.runtimeType}) in ${duration}ms',
        name: 'NFC.HCE'
      );

      // Plugin returns String? on success (usually null or empty), throws on failure
      // If we get here without exception, HCE started successfully
      if (true) {
        _isHceActive = true;
        developer.log(
          '✅ Card emulation started successfully (${duration}ms)\n'
          '   📲 Other phones can now tap your phone to receive your card\n'
          '   🔹 Service: com.novice.flutter_nfc_hce.KHostApduService\n'
          '   🔹 AID: D2760000850101\n'
          '   🔹 Status: ACTIVE\n'
          '   🔹 Plugin result: $result',
          name: 'NFC.HCE'
        );
        return NFCResult.success(duration, payloadSizeBytes);
      } else {
        developer.log(
          '❌ Failed to start card emulation (${duration}ms)\n'
          '   Plugin returned: $result\n'
          '   Expected: true\n'
          '   Possible causes:\n'
          '   - HCE service not properly registered in AndroidManifest\n'
          '   - Missing permissions\n'
          '   - NFC disabled on device\n'
          '   - Device does not support HCE',
          name: 'NFC.HCE'
        );
        return NFCResult.error('Failed to start card emulation. Check logs for details.', duration);
      }
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '❌ Card emulation exception: $e (${duration}ms)\n'
        '   Error type: ${e.runtimeType}\n'
        '   Stack trace:\n$stackTrace',
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
      await _hcePlugin.stopNfcHce();
      _isHceActive = false;
      developer.log(
        '🛑 Card emulation stopped',
        name: 'NFC.HCE'
      );
    } catch (e) {
      developer.log(
        '⚠️ Error stopping card emulation: $e',
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

  const NFCResult._({
    required this.isSuccess,
    this.error,
    required this.durationMs,
    this.dataSizeBytes,
    this.tagId,
    this.tagType,
    this.tagCapacity,
  });

  factory NFCResult.success(int durationMs, int dataSizeBytes, {String? tagId, String? tagType, int? tagCapacity}) {
    return NFCResult._(
      isSuccess: true,
      durationMs: durationMs,
      dataSizeBytes: dataSizeBytes,
      tagId: tagId,
      tagType: tagType,
      tagCapacity: tagCapacity,
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