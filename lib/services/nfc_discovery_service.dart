import 'dart:async';
import 'dart:developer' as developer;
import 'package:nfc_manager/nfc_manager.dart';

import '../core/constants/app_constants.dart';

/// Simple NFC discovery service for FAB animations only
/// Does NOT handle navigation or data processing
class NFCDiscoveryService {
  static bool _isInitialized = false;
  static Function(bool)? _onNfcDetectionChanged;
  static bool _isCurrentlyDetected = false;
  static Timer? _detectionTimer;
  static Timer? _pollingTimer;
  static bool _isPaused = false;

  /// Initialize NFC discovery for animations only
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Start listening for NFC device proximity (for FAB animation)
  static void startDiscovery({Function(bool)? onDetectionChanged}) {
    if (!_isInitialized) return;

    _onNfcDetectionChanged = onDetectionChanged;

    try {
      // Start optimized NFC detection with longer hold period
      _startOptimizedDetection();
    } catch (e) {
    }
  }

  /// Optimized NFC detection with smart polling to balance UX and performance
  static void _startOptimizedDetection() {
    try {
      // Use single session approach with extended timeout for better presence simulation
      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {

          if (!_isCurrentlyDetected) {
            _isCurrentlyDetected = true;
            _onNfcDetectionChanged?.call(true);
          }

          // Cancel any existing timeout
          _detectionTimer?.cancel();

          // Extended active period for better user experience
          // This gives users ample time to position and use their devices
          _detectionTimer = Timer(const Duration(milliseconds: NFCConstants.discoveryHoldPeriodMs), () {
            if (_isCurrentlyDetected) {
              _isCurrentlyDetected = false;
              _onNfcDetectionChanged?.call(false);

              // Restart session for next detection after a brief pause
              Timer(const Duration(milliseconds: NFCConstants.discoveryRestartDelayMs), () {
                if (_isInitialized && !_isCurrentlyDetected) {
                  _startOptimizedDetection();
                }
              });
            }
          });
        },
      );
    } catch (e) {
    }
  }

  /// Pause NFC discovery temporarily (for write operations)
  /// Keeps callback registered so discovery can resume later
  static void pauseDiscovery() {
    if (!_isInitialized || _isPaused) return;

    try {
      // Stop continuous polling
      _pollingTimer?.cancel();
      _pollingTimer = null;

      // Stop any active session
      NfcManager.instance.stopSession();

      // Clean up timers but preserve callback
      _detectionTimer?.cancel();
      _detectionTimer = null;
      _isCurrentlyDetected = false;
      _isPaused = true;

      // Notify that device is no longer detected
      _onNfcDetectionChanged?.call(false);

      developer.log('⏸️  NFC discovery paused (preserving callback)', name: 'NFC.Discovery');
    } catch (e) {
      developer.log('❌ Error pausing NFC discovery: $e', name: 'NFC.Discovery', error: e);
    }
  }

  /// Resume NFC discovery after pause
  static void resumeDiscovery() {
    if (!_isInitialized || !_isPaused) return;

    try {
      _isPaused = false;

      // Restart discovery if we have a callback
      if (_onNfcDetectionChanged != null) {
        _startOptimizedDetection();
        developer.log('▶️  NFC discovery resumed', name: 'NFC.Discovery');
      }
    } catch (e) {
      developer.log('❌ Error resuming NFC discovery: $e', name: 'NFC.Discovery', error: e);
    }
  }

  /// Stop NFC discovery completely
  static void stopDiscovery() {
    try {
      // Stop continuous polling
      _pollingTimer?.cancel();
      _pollingTimer = null;

      // Stop any active session
      NfcManager.instance.stopSession();

      // Clean up timers and state
      _detectionTimer?.cancel();
      _detectionTimer = null;
      _isCurrentlyDetected = false;
      _isPaused = false;
      _onNfcDetectionChanged = null;

      developer.log('🛑 NFC continuous polling stopped', name: 'NFC.Discovery');
    } catch (e) {
      developer.log('❌ Error stopping NFC discovery: $e', name: 'NFC.Discovery', error: e);
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

  /// Check if discovery is currently paused
  static bool get isPaused => _isPaused;

  /// Dispose the service
  static void dispose() {
    stopDiscovery();
    _isInitialized = false;
    developer.log('📱 NFC Discovery Service disposed', name: 'NFC.Discovery');
  }
}