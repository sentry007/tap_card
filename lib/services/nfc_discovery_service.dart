import 'dart:async';
import 'package:nfc_manager/nfc_manager.dart';

/// Simple NFC discovery service for FAB animations only
/// Does NOT handle navigation or data processing
class NFCDiscoveryService {
  static bool _isInitialized = false;
  static Function(bool)? _onNfcDetectionChanged;
  static bool _isCurrentlyDetected = false;
  static Timer? _detectionTimer;

  /// Initialize NFC discovery for animations only
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        print('📱 NFC not available on this device');
        return false;
      }

      _isInitialized = true;
      print('📱 NFC Discovery Service initialized for animations only');
      return true;
    } catch (e) {
      print('❌ Error initializing NFC Discovery Service: $e');
      return false;
    }
  }

  /// Start listening for NFC device proximity (for FAB animation)
  static void startDiscovery({Function(bool)? onDetectionChanged}) {
    if (!_isInitialized) return;

    _onNfcDetectionChanged = onDetectionChanged;

    try {
      // Start NFC session for proximity detection only
      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          print('🎯 NFC device detected - maintaining FAB animation');

          // Set detection state if not already set
          if (!_isCurrentlyDetected) {
            print('🎯 NFC device first detected - activating FAB animation');
            _isCurrentlyDetected = true;
            _onNfcDetectionChanged?.call(true);
          }

          // Cancel any existing timer
          _detectionTimer?.cancel();

          // Quick timeout for responsive feedback - device moved away detection
          _detectionTimer = Timer(const Duration(milliseconds: 800), () {
            if (_isCurrentlyDetected) {
              print('🎯 NFC device moved away - resetting FAB state');
              _isCurrentlyDetected = false;
              _onNfcDetectionChanged?.call(false);
            }
          });
        },
      );

      print('🎯 NFC discovery started - listening for device proximity');
    } catch (e) {
      print('❌ Error starting NFC discovery: $e');
    }
  }

  /// Stop NFC discovery
  static void stopDiscovery() {
    try {
      NfcManager.instance.stopSession();
      _detectionTimer?.cancel();
      _detectionTimer = null;
      _isCurrentlyDetected = false;
      _onNfcDetectionChanged = null;
      print('🛑 NFC discovery stopped');
    } catch (e) {
      print('❌ Error stopping NFC discovery: $e');
    }
  }

  /// Check if NFC is available
  static Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      return false;
    }
  }

  /// Check if NFC device is currently detected
  static bool get isNfcDetected => _isCurrentlyDetected;

  /// Dispose the service
  static void dispose() {
    stopDiscovery();
    _isInitialized = false;
    print('📱 NFC Discovery Service disposed');
  }
}