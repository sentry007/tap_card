import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/profile_service.dart';
import '../../services/token_manager_service.dart';
import '../../services/nfc_service.dart';
import '../../services/nfc_discovery_service.dart';
import '../../services/nfc_settings_service.dart';
import '../../core/constants/routes.dart';
import '../../core/constants/app_constants.dart';
import '../../models/unified_models.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import '../../widgets/history/method_chip.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Five-state NFC FAB system for comprehensive user feedback
enum NfcFabState {
  inactive,  // Dull white icon, no animations
  active,    // Glowing white, breathing + ripple
  writing,   // Loading spinner during NFC write
  success,   // Green checkmark after successful write
  error      // Red X after failed write
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  late AnimationController _pulseController;
  late AnimationController _contactsController;
  late AnimationController _rippleController;
  late AnimationController _successController;

  late Animation<double> _fabScale;
  late Animation<double> _fabGlow;
  late Animation<double> _pulseScale;
  late Animation<double> _contactsSlide;
  late Animation<double> _rippleWave;
  late Animation<double> _successScale;

  bool _isNfcLoading = false;
  bool _isContactsLoading = false;
  bool _isPreviewMode = false; // Toggle between share mode and preview mode
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  bool _nfcAvailable = false;
  bool _nfcDeviceDetected = false;

  // NFC FAB state
  NfcFabState _nfcFabState = NfcFabState.inactive;
  NfcMode _nfcMode = NfcMode.tagWrite; // Default to tag write mode
  late NotificationService _notificationService;
  late ProfileService _profileService;
  late TokenManagerService _tokenManager;

  // NFC Performance Optimization: Pre-cached data for instant sharing
  ProfileData? _cachedActiveProfile;       // Pre-cached active profile
  Map<String, String>? _cachedDualPayload; // Pre-cached dual-payload (vCard + URL)
  bool _isPayloadReady = false;            // True when payload is cached and ready

  // State reset timer for success/error states
  Timer? _stateResetTimer;

  // Mock recent contacts data
  List<Contact> _recentContacts = [];

  @override
  void initState() {
    super.initState();
    _initServices();
    _initAnimations();
    _loadContacts();
    _preCacheNfcPayload(); // Pre-cache for instant NFC sharing
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh cache when returning to screen or when profile data changes
    // This ensures payload stays fresh without requiring app restart
    developer.log('🔄 Refreshing NFC cache (screen resumed or data changed)', name: 'Home.NFC');
    _preCacheNfcPayload();
  }

  void _initServices() {
    _notificationService = NotificationService();
    _profileService = ProfileService();
    _tokenManager = TokenManagerService();

    // Initialize services
    _initializeNFC();
    _initializeHistory();
    _loadNfcSettings();

    // Setup notification callback
    _notificationService.setCardReceivedCallback(_handleCardReceived);

    // NFC state changes handled in simplified service

    // Clean up expired tokens on app start
    _tokenManager.cleanupExpiredTokens();
  }

  /// Load NFC settings including default mode
  Future<void> _loadNfcSettings() async {
    await NfcSettingsService.initialize();
    final defaultMode = await NfcSettingsService.getDefaultMode();

    if (mounted) {
      setState(() {
        _nfcMode = defaultMode;
      });
      developer.log(
        '⚙️ Loaded default NFC mode: ${defaultMode.name}',
        name: 'Home.Settings'
      );
    }
  }

  Future<void> _initializeHistory() async {
    await HistoryService.initialize();
  }

  Future<void> _initializeNFC() async {
    _nfcAvailable = await NFCService.initialize();
    if (!_nfcAvailable) {
      _showNfcSetupDialog();
    }

    // Initialize NFC discovery for FAB animations
    if (_nfcAvailable) {
      await NFCDiscoveryService.initialize();
      _startNfcDiscovery();
    }
  }

  void _startNfcDiscovery() {
    NFCDiscoveryService.startDiscovery(
      onDetectionChanged: (bool detected) {
        if (mounted) {
          setState(() {
            _nfcDeviceDetected = detected;
          });

          // ONLY animate ripple when in ACTIVE state
          if (_nfcFabState == NfcFabState.active && detected) {
            _rippleController.repeat();
          } else if (!detected) {
            _rippleController.stop();
            _rippleController.reset();
          }
        }
      },
    );
  }

  // Simplified NFC state handling
  void _updateNfcUI() {
    if (mounted) {
      setState(() {
        // Update UI based on NFC availability
      });
    }
  }

  void _handleCardReceived(Map<String, dynamic> cardData) {
    if (mounted) {
      _notificationService.showInAppNotification(context, cardData);
    }
  }

  void _initAnimations() {
    // Optimized animation controllers with better performance
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300), // Faster for responsiveness
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200), // Faster and synchronized with ripple
      vsync: this,
    );

    _contactsController = AnimationController(
      duration: const Duration(milliseconds: 500), // Snappier
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1500), // Synchronized with pulse for organic feel
      vsync: this,
    );

    // Create optimized animations with better curves
    _fabScale = Tween<double>(
      begin: 1.0,
      end: 0.92, // Slightly more pronounced
    ).animate(CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    ));

    _fabGlow = Tween<double>(
      begin: 0.25,
      end: 0.7, // Enhanced glow range
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine, // Smoother sine wave
    ));

    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.08, // Subtle but noticeable
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    ));

    _contactsSlide = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _contactsController,
      curve: Curves.easeOutCubic,
    ));

    _rippleWave = Tween<double>(
      begin: 0.0,
      end: 2.2, // Slightly larger ripple
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOutQuart, // Better ripple effect
    ));

    // Success animation controller
    _successController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _successScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    // Start the breathing pulse animation - key UX element
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadContacts() async {
    setState(() => _isContactsLoading = true);

    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _recentContacts = _generateMockContacts();
        _isContactsLoading = false;
      });
      _contactsController.forward();
    }
  }

  List<Contact> _generateMockContacts() {
    return [
      Contact(name: 'John Doe', avatar: '👨‍💼', lastShared: '2 min ago'),
      Contact(name: 'Sarah Smith', avatar: '👩‍💻', lastShared: '1 hour ago'),
      Contact(name: 'Mike Johnson', avatar: '👨‍🎨', lastShared: '3 hours ago'),
      Contact(name: 'Emily Brown', avatar: '👩‍🔬', lastShared: 'Yesterday'),
      Contact(name: 'Alex Wilson', avatar: '👨‍🚀', lastShared: '2 days ago'),
    ];
  }


  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await _loadContacts();
  }

  void _onNfcTap() async {
    developer.log('🔥 FAB button tapped - _onNfcTap() called', name: 'Home.NFC');
    developer.log('   Current mode: ${_nfcMode == NfcMode.tagWrite ? "Tag Write" : "P2P Share"}', name: 'Home.NFC');
    HapticFeedback.mediumImpact();

    // Route based on current NFC mode
    if (_nfcMode == NfcMode.tagWrite) {
      // TAG WRITE MODE
      if (_nfcFabState == NfcFabState.inactive) {
        await _activateNfcWriteMode();
      } else {
        await _deactivateNfcWriteMode();
      }
    } else {
      // P2P SHARE MODE
      if (_nfcFabState == NfcFabState.inactive) {
        await _activateP2pMode();
      } else {
        await _deactivateP2pMode();
      }
    }
  }

  /// Show mode picker bottom sheet
  void _showModePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Select NFC Mode',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.glassBorder.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _buildModeToggleOption(
                      icon: CupertinoIcons.tag_fill,
                      title: 'Tag Write',
                      subtitle: 'Write to physical NFC tags',
                      isSelected: _nfcMode == NfcMode.tagWrite,
                      color: AppColors.primaryAction,
                      onTap: () {
                        Navigator.pop(context);
                        _switchToMode(NfcMode.tagWrite);
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildModeToggleOption(
                      icon: CupertinoIcons.radiowaves_right,
                      title: 'P2P Share',
                      subtitle: 'Phone-to-phone sharing',
                      isSelected: _nfcMode == NfcMode.p2pShare,
                      color: AppColors.p2pPrimary,
                      isAvailable: NFCService.isHceSupported,
                      onTap: () {
                        Navigator.pop(context);
                        if (NFCService.isHceSupported) {
                          _switchToMode(NfcMode.p2pShare);
                        } else {
                          _showErrorMessage('Phone-to-Phone mode not supported on this device');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    bool isAvailable = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.surfaceMedium.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isAvailable ? AppColors.textTertiary : AppColors.textDisabled),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isAvailable ? AppColors.textPrimary : AppColors.textDisabled),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  /// Switch to a new NFC mode
  void _switchToMode(NfcMode newMode) {
    if (_nfcMode == newMode) return;

    setState(() {
      _nfcMode = newMode;
    });

    NFCService.switchMode(newMode);
    HapticFeedback.lightImpact();

    final modeName = newMode == NfcMode.tagWrite ? 'Tag Write' : 'Phone-to-Phone';
    _showInfoMessage('Switched to $modeName mode');
  }

  /// Activate NFC write mode - FAB goes to "active" state
  Future<void> _activateNfcWriteMode() async {
    developer.log('🔥 Activating NFC write mode', name: 'Home.NFC');
    _fabController.forward().then((_) => _fabController.reverse());

    developer.log('🔍 Checking NFC availability - _nfcAvailable: $_nfcAvailable', name: 'Home.NFC');
    if (!_nfcAvailable) {
      developer.log('❌ NFC not available, showing setup dialog', name: 'Home.NFC');
      _showNfcSetupDialog();
      return;
    }

    // ⚡ PERFORMANCE: Check if dual-payload is cached and ready (INSTANT check)
    developer.log('🔍 Checking cached dual-payload - _isPayloadReady: $_isPayloadReady', name: 'Home.NFC');
    if (!_isPayloadReady || _cachedDualPayload == null) {
      developer.log('⚠️ Dual-payload not ready, attempting to cache now...', name: 'Home.NFC');
      _showErrorMessage('Profile not ready. Please wait a moment...');
      await _preCacheNfcPayload(); // Try to cache now
      if (!_isPayloadReady || _cachedDualPayload == null) {
        return;
      }
    }

    developer.log(
      '✅ Using cached DUAL-PAYLOAD (INSTANT - 0ms lag!)\n'
      '   • vCard: ${_cachedDualPayload!['vcard']!.length} bytes\n'
      '   • URL: ${_cachedDualPayload!['url']!.length} bytes',
      name: 'Home.NFC'
    );

    // CRITICAL: Pause NFC discovery service to prevent session conflicts
    developer.log('⏸️ Pausing NFC discovery service before write...', name: 'Home.NFC');
    NFCDiscoveryService.pauseDiscovery();

    // Change FAB state to ACTIVE (waiting for tag)
    setState(() {
      _nfcFabState = NfcFabState.active;
    });

    // Start breathing and ripple animations for active state
    _pulseController.repeat(reverse: true);
    _rippleController.repeat();

    try {
      // IMPORTANT: Don't show dialog - it pauses the activity and breaks foreground dispatch!
      // Show visual feedback on FAB instead

      // ⚡ Generate payload WITH METADATA (share context includes timestamp & method)
      developer.log('🚀 Generating payload with share context...', name: 'Home.NFC');
      final startTime = DateTime.now();

      // Create share context with current timestamp
      final shareContext = ShareContext(
        method: ShareMethod.nfc,
        timestamp: DateTime.now(),
      );

      // Generate fresh payload WITH metadata (adds ~40 bytes)
      final payload = _cachedActiveProfile!.getDualPayloadWithContext(shareContext);

      // Stay in ACTIVE state (breathing + ripples) until write completes
      // Writes are instant once tag is detected, so no loading state needed
      final result = await NFCService.writeData(payload);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log('⏱️ NFC operation completed in ${duration}ms', name: 'Home.NFC');
      developer.log('📊 NFCService returned: ${result.toString()}', name: 'Home.NFC');

      // Stop animations before transitioning to success/error
      _pulseController.stop();
      _rippleController.stop();

      if (mounted) {
        if (result.isSuccess) {
          // SUCCESS state - instant transition from active
          setState(() {
            _nfcFabState = NfcFabState.success;
          });
          _successController.forward();
          _showSuccessMessage('Written to NFC tag! 🎉');
          _scheduleStateReset(duration: const Duration(seconds: 2));

          // Add to history with actual tag metadata from hardware
          _addNfcWriteToHistory(result);
        } else {
          // ERROR state - instant transition from active
          setState(() {
            _nfcFabState = NfcFabState.error;
          });
          if (result.error == 'Timeout') {
            _showErrorMessage('No NFC tag detected. Bring tag within 4cm and try again.');
          } else {
            _showErrorMessage('NFC write failed: ${result.error}');
          }
          _scheduleStateReset(duration: const Duration(seconds: 3));
        }
      }
    } catch (e) {
      developer.log('❌ Exception in _activateNfcWriteMode(): $e', name: 'Home.NFC', error: e);
      if (mounted) {
        setState(() {
          _nfcFabState = NfcFabState.error;
        });
        _showErrorMessage('Failed to activate NFC: $e');
        _scheduleStateReset(duration: const Duration(seconds: 3));
      }
    } finally {
      // CRITICAL: Always resume discovery service, even on errors
      developer.log('▶️ Resuming NFC discovery service after write...', name: 'Home.NFC');
      NFCDiscoveryService.resumeDiscovery();
    }
  }

  /// Deactivate NFC write mode - Cancel operation
  Future<void> _deactivateNfcWriteMode() async {
    developer.log('🔥 Deactivating NFC write mode (user cancelled)', name: 'Home.NFC');
    HapticFeedback.lightImpact();

    // Call native to cancel write mode
    try {
      await NFCService.cancelSession();
    } catch (e) {
      developer.log('⚠️ Failed to cancel NFC session: $e', name: 'Home.NFC', error: e);
    }

    if (mounted) {
      setState(() {
        _nfcFabState = NfcFabState.inactive;
      });
      _pulseController.stop();
      _rippleController.stop();
      _pulseController.reset();
      _rippleController.reset();
      _showInfoMessage('NFC write cancelled');
    }

    // Resume NFC discovery service after cancellation
    developer.log('▶️ Resuming NFC discovery service after cancellation...', name: 'Home.NFC');
    NFCDiscoveryService.resumeDiscovery();
  }

  /// Activate P2P mode - Phone acts as NFC tag via HCE
  Future<void> _activateP2pMode() async {
    developer.log('🔥 Activating P2P Share mode (HCE)', name: 'Home.P2P');
    _fabController.forward().then((_) => _fabController.reverse());

    developer.log('🔍 Checking HCE availability - isHceSupported: ${NFCService.isHceSupported}', name: 'Home.P2P');
    if (!NFCService.isHceSupported) {
      developer.log('❌ HCE not supported on this device', name: 'Home.P2P');
      _showErrorMessage('Phone-to-Phone mode not supported on this device');
      return;
    }

    // Check if dual-payload is ready
    developer.log('🔍 Checking cached dual-payload - _isPayloadReady: $_isPayloadReady', name: 'Home.P2P');
    if (!_isPayloadReady || _cachedDualPayload == null) {
      developer.log('⚠️ Dual-payload not ready, attempting to cache now...', name: 'Home.P2P');
      _showErrorMessage('Profile not ready. Please wait a moment...');
      await _preCacheNfcPayload();
      if (!_isPayloadReady || _cachedDualPayload == null) {
        return;
      }
    }

    developer.log(
      '✅ Using cached DUAL-PAYLOAD for P2P (INSTANT - 0ms lag!)\n'
      '   • vCard: ${_cachedDualPayload!['vcard']!.length} bytes\n'
      '   • URL: ${_cachedDualPayload!['url']!.length} bytes',
      name: 'Home.P2P'
    );

    // CRITICAL: Pause NFC discovery service to prevent conflicts
    developer.log('⏸️ Pausing NFC discovery service before HCE...', name: 'Home.P2P');
    NFCDiscoveryService.pauseDiscovery();

    // Change FAB state to ACTIVE
    setState(() {
      _nfcFabState = NfcFabState.active;
    });

    // Start breathing and ripple animations
    _pulseController.repeat(reverse: true);
    _rippleController.repeat();

    try {
      developer.log(
        '🚀 Starting P2P Card Emulation with vCard (Universal Compatibility)\n'
        '   📇 Payload: vCard 3.0 format\n'
        '   🌐 Any phone can now save contact - no app needed!',
        name: 'Home.P2P'
      );
      final startTime = DateTime.now();

      // For P2P/HCE, use vCard for universal compatibility
      // Any phone can now save the contact, even without our app installed!
      // The vCard includes URL field that opens full digital card in browser
      final vCardPayload = _cachedDualPayload!['vcard']!;

      developer.log(
        '📦 P2P vCard payload ready\n'
        '   • Size: ${vCardPayload.length} bytes\n'
        '   • Format: vCard 3.0 (universal standard)\n'
        '   • Contains: Name, Phone, Email, Company, URL',
        name: 'Home.P2P'
      );

      final result = await NFCService.startCardEmulation(vCardPayload);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log('⏱️ P2P operation completed in ${duration}ms', name: 'Home.P2P');
      developer.log('📊 NFCService returned: ${result.toString()}', name: 'Home.P2P');

      if (mounted) {
        if (result.isSuccess) {
          // Keep in ACTIVE state - HCE is now running and waiting for tap
          developer.log(
            '✅ P2P mode activated successfully\n'
            '   📲 Your phone is now acting as an NFC tag\n'
            '   👉 Other phones can tap to receive your card\n'
            '   🔹 Status: ACTIVE and waiting\n'
            '   🔹 Tap FAB again to stop sharing',
            name: 'Home.P2P'
          );
          _showSuccessMessage('Ready! Hold phones together to share');

          // Add P2P share to history
          _addP2pShareToHistory();
        } else {
          // ERROR state
          _pulseController.stop();
          _rippleController.stop();
          setState(() {
            _nfcFabState = NfcFabState.error;
          });
          developer.log('❌ Failed to start P2P mode: ${result.error}', name: 'Home.P2P');
          _showErrorMessage('Failed to start P2P mode: ${result.error}');
          _scheduleStateReset(duration: const Duration(seconds: 3));
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Exception in _activateP2pMode(): $e',
        name: 'Home.P2P',
        error: e,
        stackTrace: stackTrace
      );
      if (mounted) {
        _pulseController.stop();
        _rippleController.stop();
        setState(() {
          _nfcFabState = NfcFabState.error;
        });
        _showErrorMessage('Failed to activate P2P: $e');
        _scheduleStateReset(duration: const Duration(seconds: 3));
      }
    } finally {
      // Note: DON'T resume discovery service here - keep it paused while HCE is active
      developer.log('ℹ️ Discovery service remains paused while P2P mode is active', name: 'Home.P2P');
    }
  }

  /// Deactivate P2P mode - Stop HCE
  Future<void> _deactivateP2pMode() async {
    developer.log('🔥 Deactivating P2P mode (user cancelled or completed)', name: 'Home.P2P');
    HapticFeedback.lightImpact();

    // Stop HCE card emulation
    try {
      developer.log('🛑 Calling NFCService.stopCardEmulation()...', name: 'Home.P2P');
      await NFCService.stopCardEmulation();
      developer.log('✅ HCE stopped successfully', name: 'Home.P2P');
    } catch (e) {
      developer.log('⚠️ Failed to stop HCE: $e', name: 'Home.P2P', error: e);
    }

    if (mounted) {
      setState(() {
        _nfcFabState = NfcFabState.inactive;
      });
      _pulseController.stop();
      _rippleController.stop();
      _pulseController.reset();
      _rippleController.reset();
      _showInfoMessage('P2P sharing stopped');
    }

    // Resume NFC discovery service after deactivation
    developer.log('▶️ Resuming NFC discovery service after P2P deactivation...', name: 'Home.P2P');
    NFCDiscoveryService.resumeDiscovery();
  }

  /// Schedule automatic reset from success/error state to inactive
  void _scheduleStateReset({required Duration duration}) {
    _stateResetTimer?.cancel();
    _stateResetTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _nfcFabState = NfcFabState.inactive;
        });
        _successController.reset();
      }
    });
  }

  void _showShareModal() {
    // ✅ Ensure profile is ready before showing modal
    if (_cachedActiveProfile == null) {
      _showErrorMessage('Profile not ready. Please wait...');
      _preCacheNfcPayload();
      return;
    }

    ShareModal.show(
      context,
      userName: _cachedActiveProfile!.name,
      userEmail: _cachedActiveProfile!.email ?? '',
      profileImageUrl: _cachedActiveProfile!.profileImagePath,
      profile: _cachedActiveProfile!,  // Pass full profile for metadata generation
      onNFCShare: _onNfcTap,
    );
  }

  void _showNfcSetupDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.primaryAction.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.antenna_radiowaves_left_right,
                        color: AppColors.primaryAction,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Enable NFC',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'NFC is required to share your contact card. Please enable NFC in your device settings to continue.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.primaryAction,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openNfcSettings();
                      },
                      child: const Text(
                        'Open Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNfcScanningDialog() {
    GlassmorphicDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryAction.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          CupertinoIcons.antenna_radiowaves_left_right,
          color: AppColors.primaryAction,
          size: 32,
        ),
      ),
      title: 'NFC Scanning...',
      content: 'Bring your phone close to:\n• Another NFC-enabled phone or device\n• An NFC tag to write your profile\n\nKeep devices within 4cm of each other.',
      actions: [
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            await NFCService.cancelSession('User cancelled');
            if (mounted) {
              setState(() => _isNfcLoading = false);
            }
          },
        ),
      ],
    );
  }

  void _openNfcSettings() async {
    try {
      // Try to open NFC settings using app_settings
      await _tryOpenNfcSettings();

      // Add a delay to give user time to toggle NFC
      await Future.delayed(const Duration(milliseconds: 500));

      // After user returns from settings, refresh NFC status
      if (mounted) {
        _nfcAvailable = await NFCService.initialize();

        // Show result based on NFC state
        if (_nfcAvailable) {
          _showSuccessMessage('NFC is now enabled! You can share your card.');
        } else {
          _showInfoMessage('Please enable NFC in settings to use tap-to-share features.');
        }
      }
    } catch (e) {
      debugPrint('Error opening NFC settings: $e');
      if (mounted) {
        _showErrorMessage('Could not open settings. Please enable NFC manually.');
      }
    }
  }

  Future<void> _tryOpenNfcSettings() async {
    // Open app settings or NFC-specific settings
    // Note: On Android, AppSettings.openAppSettings() opens the app settings page
    // Users can then navigate to NFC settings from there
    // iOS doesn't support NFC settings programmatically
    await AppSettings.openAppSettings();
  }

  void _showNfcInstructionsDialog() {
    if (!mounted) return;

    final dialogContext = context;

    GlassmorphicDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryAction.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          CupertinoIcons.settings,
          color: AppColors.primaryAction,
          size: 32,
        ),
      ),
      title: 'Enable NFC Manually',
      content: 'To enable NFC:\n\n1. Go to Settings\n2. Find "Connections" or "Wireless & Networks"\n3. Look for "NFC" and turn it on\n4. Come back and check again',
      actions: [
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          },
        ),
        DialogAction.primary(
          text: 'Check Again',
          onPressed: () => _checkNfcStatusAgain(),
        ),
      ],
    );
  }

  void _checkNfcStatusAgain() async {
    try {
      // Close the current dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Show loading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAction.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryAction.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Checking NFC status...'),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh NFC status
        _nfcAvailable = await NFCService.initialize();

        // Show result
        if (_nfcAvailable) {
          _showSuccessMessage('Great! NFC is now enabled. You can share your card.');
        } else {
          _showErrorMessage('NFC is still disabled. Please enable it in your device settings.');
        }
      }
    } catch (e) {
      debugPrint('Error checking NFC status: $e');
      if (mounted) {
        _showErrorMessage('Failed to check NFC status. Please try again.');
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.exclamationmark_circle_fill, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.info_circle_fill, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onSettingsTap() {
    HapticFeedback.lightImpact();
    context.go(AppRoutes.settings);
  }

  /// Get active profile for NFC sharing
  Future<ProfileData?> _getActiveProfileForSharing() async {
    try {
      final profiles = _profileService.profiles;

      // Find the first active profile
      for (final profile in profiles) {
        if (profile.isActive && profile.name.isNotEmpty) {
          return profile;
        }
      }

      // If no active profile, return the first profile with a name
      for (final profile in profiles) {
        if (profile.name.isNotEmpty) {
          return profile;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting active profile: $e');
      return null;
    }
  }

  /// Pre-cache active profile and NFC payload for instant sharing
  ///
  /// This method runs at startup and whenever the profile changes,
  /// ensuring the NFC tap handler has everything ready immediately.
  Future<void> _preCacheNfcPayload() async {
    try {
      developer.log('⚡ Pre-caching DUAL-PAYLOAD for instant NFC sharing...', name: 'Home.NFC');
      final startTime = DateTime.now();

      // Get active profile (synchronous from service)
      final profile = await _getActiveProfileForSharing();

      if (profile == null) {
        developer.log('⚠️ No active profile found for caching', name: 'Home.NFC');
        if (mounted) {
          setState(() {
            _cachedActiveProfile = null;
            _cachedDualPayload = null;
            _isPayloadReady = false;
          });
        }
        return;
      }

      // Get cached DUAL-PAYLOAD (vCard + URL) - should be pre-generated for 0ms lag!
      final dualPayload = profile.dualPayload;

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '✅ Dual-payload cached in ${duration}ms (INSTANT!)\n'
        '   • vCard: ${dualPayload['vcard']!.length} bytes\n'
        '   • URL: ${dualPayload['url']!.length} bytes\n'
        '   • Total: ${dualPayload['vcard']!.length + dualPayload['url']!.length} bytes\n'
        '   • Profile: ${profile.name}',
        name: 'Home.NFC'
      );

      if (mounted) {
        setState(() {
          _cachedActiveProfile = profile;
          _cachedDualPayload = dualPayload;
          _isPayloadReady = true;
        });
      }
    } catch (e) {
      developer.log('❌ Error pre-caching dual-payload: $e', name: 'Home.NFC', error: e);
      if (mounted) {
        setState(() {
          _cachedActiveProfile = null;
          _cachedDualPayload = null;
          _isPayloadReady = false;
        });
      }
    }
  }

  /// Store token for profile before sharing
  Future<void> _storeTokenForProfile(ProfileData profile, String userId) async {
    try {
      final token = ShareToken.generateLocal(userId);
      await _tokenManager.storeToken(
        token: token,
        profileData: profile,
      );
      debugPrint('Token stored for sharing: ${token.token}');
    } catch (e) {
      debugPrint('Error storing token: $e');
    }
  }

  /// Get current location if tracking is enabled
  Future<String?> _getCurrentLocation() async {
    try {
      // Check if location tracking is enabled in settings
      final isEnabled = await NfcSettingsService.getLocationTrackingEnabled();
      if (!isEnabled) {
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          developer.log('Location permission denied', name: 'Home.Location');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        developer.log('Location permission denied forever', name: 'Home.Location');
        return null;
      }

      // Get location with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      // Attempt reverse geocoding to get human-readable location
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // Format: "City, State" or "City, Country"
          final locationParts = [
            place.locality,          // City
            place.administrativeArea // State/Province
          ].where((e) => e != null && e.isNotEmpty).toList();

          if (locationParts.isNotEmpty) {
            final location = locationParts.join(', ');
            developer.log('📍 Location: $location', name: 'Home.Location');
            return location;
          }
        }

        developer.log('⚠️ Reverse geocoding returned no placemarks', name: 'Home.Location');
      } catch (geocodeError) {
        developer.log('⚠️ Reverse geocoding failed, using coordinates',
          name: 'Home.Location', error: geocodeError);
      }

      // Fallback to coordinates if reverse geocoding fails
      final location = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      developer.log('📍 Location (coordinates): $location', name: 'Home.Location');
      return location;
    } catch (e) {
      developer.log('Failed to get location: $e', name: 'Home.Location', error: e);
      return null;
    }
  }

  /// Add NFC tag write to history with actual tag metadata from hardware
  Future<void> _addNfcWriteToHistory(NFCResult result) async {
    try {
      final location = await _getCurrentLocation();

      // Use actual tag data from NFCResult, with fallbacks
      final tagId = result.tagId ?? 'TAG_${DateTime.now().millisecondsSinceEpoch}';
      final tagCapacity = result.tagCapacity;
      final tagType = _inferTagTypeFromCapacity(tagCapacity);

      await HistoryService.addTagEntry(
        profileName: _profileService.activeProfile?.name ?? 'Unknown Profile',
        tagId: tagId,
        tagType: tagType,
        method: ShareMethod.tag,
        tagCapacity: tagCapacity,
        location: location,
      );

      final locationStr = location != null ? ' at $location' : '';
      final capacityStr = tagCapacity != null ? ' ($tagCapacity bytes)' : '';
      developer.log(
        '✅ NFC write added to history: $tagId ($tagType$capacityStr)$locationStr',
        name: 'Home.History'
      );
    } catch (e) {
      developer.log('❌ Error adding NFC write to history: $e', name: 'Home.History', error: e);
    }
  }

  /// Add P2P share to history
  Future<void> _addP2pShareToHistory() async {
    try {
      final location = await _getCurrentLocation();

      await HistoryService.addSentEntry(
        recipientName: 'Via P2P Share',
        method: ShareMethod.nfc,
        location: location,
        metadata: {
          'mode': 'p2p_hce',
          'activationTime': DateTime.now().toIso8601String(),
        },
      );

      final locationStr = location != null ? ' at $location' : '';
      developer.log(
        '✅ P2P share added to history$locationStr',
        name: 'Home.History'
      );
    } catch (e) {
      developer.log('❌ Error adding P2P share to history: $e', name: 'Home.History', error: e);
    }
  }

  /// Infer tag type from actual hardware capacity
  String _inferTagTypeFromCapacity(int? capacity) {
    if (capacity == null) return 'NTAG';
    if (capacity >= 888) return 'NTAG216';
    if (capacity >= 504) return 'NTAG215';
    if (capacity >= 144) return 'NTAG213';
    return 'NTAG';
  }

  // Launch methods for ProfileCardPreview interactions
  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      Uri uri;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        uri = Uri.parse('https://$url');
      } else {
        uri = Uri.parse(url);
      }

      // Skip canLaunchUrl check - it's unreliable and may return false even when launchUrl works
      // Just try to launch directly and handle errors
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Show error only if launchUrl actually fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $url'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _launchSocialMedia(String platform, String url) async {
    try {
      // 1. Try to open native app first
      final appUri = _getSocialAppUri(platform, url);
      if (appUri != null && await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }

      // 2. Fall back to web URL
      String finalUrl = url;
      if (!url.startsWith('http')) {
        finalUrl = _getSocialUrl(platform, url);
      }
      await _launchUrl(finalUrl);
    } catch (e) {
      // If all fails, show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $platform link'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Get native app URI for social platform
  /// Returns null if platform doesn't support app schemes
  Uri? _getSocialAppUri(String platform, String username) {
    final cleanUsername = username.startsWith('@')
      ? username.substring(1)
      : username;

    // Skip if already a full URL
    if (username.startsWith('http')) return null;

    try {
      switch (platform.toLowerCase()) {
        case 'instagram':
          return Uri.parse('instagram://user?username=$cleanUsername');
        case 'twitter':
        case 'x':
          return Uri.parse('twitter://user?screen_name=$cleanUsername');
        case 'linkedin':
          return Uri.parse('linkedin://profile/$cleanUsername');
        case 'github':
          return Uri.parse('github://$cleanUsername');
        case 'tiktok':
          return Uri.parse('tiktok://user?username=$cleanUsername');
        case 'youtube':
          return Uri.parse('youtube://user/$cleanUsername');
        case 'facebook':
          return Uri.parse('fb://profile/$cleanUsername');
        case 'snapchat':
          return Uri.parse('snapchat://add/$cleanUsername');
        case 'behance':
        case 'dribbble':
        case 'discord':
          // These don't have reliable user schemes
          return null;
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  String _getSocialUrl(String platform, String username) {
    final cleanUsername = username.startsWith('@') ? username.substring(1) : username;
    switch (platform.toLowerCase()) {
      case 'linkedin':
        return 'https://linkedin.com/in/$cleanUsername';
      case 'twitter':
      case 'x':
        return 'https://twitter.com/$cleanUsername';
      case 'github':
        return 'https://github.com/$cleanUsername';
      case 'instagram':
        return 'https://instagram.com/$cleanUsername';
      case 'behance':
        return 'https://behance.net/$cleanUsername';
      case 'dribbble':
        return 'https://dribbble.com/$cleanUsername';
      case 'tiktok':
        return 'https://tiktok.com/@$cleanUsername';
      case 'youtube':
        return 'https://youtube.com/@$cleanUsername';
      default:
        return username;
    }
  }

  @override
  void dispose() {
    // Cancel state reset timer
    _stateResetTimer?.cancel();

    // Stop P2P emulation if active
    if (_nfcMode == NfcMode.p2pShare && _nfcFabState == NfcFabState.active) {
      developer.log('🛑 Stopping P2P emulation (leaving page)', name: 'Home.P2P');
      NFCService.stopCardEmulation();
    }

    // Stop NFC discovery
    NFCDiscoveryService.dispose();

    // Dispose animation controllers
    _fabController.dispose();
    _pulseController.dispose();
    _contactsController.dispose();
    _rippleController.dispose();
    _successController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: const Key('home-screen'),
      body: Stack(
        children: [
          // Background gradient (full screen behind everything)
          Positioned.fill(
            child: Container(
              key: const Key('home-background'),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBackground,
                    AppColors.surfaceDark,
                  ],
                ),
              ),
            ),
          ),
          // Content scrolls from top
          RefreshIndicator(
            key: _refreshKey,
            onRefresh: _onRefresh,
            color: AppColors.primaryAction,
            backgroundColor: AppColors.surfaceDark,
            child: SingleChildScrollView(
              key: const Key('home-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                key: const Key('home-layout'),
                children: [
                  SizedBox(height: statusBarHeight + 80 + 40), // App bar space + original spacing
                  _isPreviewMode ? _buildCardPreview() : _buildHeroNfcFab(),
                  const SizedBox(height: 16),
                  _isPreviewMode ? _buildPreviewText() : _buildTapToShareText(),
                  const SizedBox(height: 60),
                  _buildRecentContactsStrip(),
                  const SizedBox(height: 32),
                  _buildRecentHistoryStrip(),
                  const SizedBox(height: 80), // Space for bottom nav
                ],
              ),
            ),
          ),
          // App bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassAppBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar() {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.only(
        top: statusBarHeight + 16,
        left: 16,
        right: 16,
      ),
      child: SizedBox(
        key: const Key('appbar-container'),
        height: 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              key: const Key('appbar-glass'),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                key: const Key('appbar-content'),
                children: [
                  _buildModeToggle(),
                  const Spacer(),
                  // Logo section
                  Row(
                    key: const Key('appbar-logo'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.antenna_radiowaves_left_right,
                          color: AppColors.textPrimary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap Card',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildAppBarIcon(CupertinoIcons.settings, _onSettingsTap, 'settings'),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap, String keyName) {
    return Material(
      key: Key('home_appbar_${keyName}_material'),
      color: Colors.transparent,
      child: InkWell(
        key: Key('home_appbar_${keyName}_inkwell'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: Key('home_appbar_${keyName}_container'),
          width: 40, // 8px * 5
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            key: Key('home_appbar_${keyName}_icon'),
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Material(
      key: const Key('home_mode_toggle_material'),
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home_mode_toggle_inkwell'),
        onTap: () {
          setState(() => _isPreviewMode = !_isPreviewMode);
          HapticFeedback.lightImpact();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: const Key('home_mode_toggle_container'),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isPreviewMode ? CupertinoIcons.antenna_radiowaves_left_right : CupertinoIcons.eye,
            key: const Key('home_mode_toggle_icon'),
            color: _isPreviewMode
              ? AppColors.primaryAction
              : AppColors.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroNfcFab() {
    return AnimatedBuilder(
      key: const Key('nfc-fab'),
      animation: Listenable.merge([_fabController, _pulseController, _rippleController]),
      builder: (context, child) {
        // Get NFC state colors for dynamic theming
        final nfcColors = _getNfcStateColors();
        final hasDevice = _nfcDeviceDetected;

        return Transform.scale(
          scale: _fabScale.value * _pulseScale.value * (hasDevice ? 1.05 : 1.0),
          child: Container(
            key: const Key('nfc-fab-container'),
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated outer glow effect
                Container(
                  key: const Key('nfc-fab-glow'),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: nfcColors['primary']!.withOpacity(
                          (hasDevice ? _fabGlow.value * 1.5 : _fabGlow.value).clamp(0.0, 1.0),
                        ),
                        blurRadius: hasDevice ? 50 : 40,
                        spreadRadius: hasDevice ? 8 : 4,
                      ),
                      BoxShadow(
                        color: nfcColors['secondary']!.withOpacity(
                          (hasDevice ? _fabGlow.value : _fabGlow.value * 0.7).clamp(0.0, 1.0),
                        ),
                        blurRadius: hasDevice ? 45 : 35,
                        spreadRadius: hasDevice ? 6 : 2,
                      ),
                    ],
                  ),
                ),
                // Ripple wave animation matching FAB shape - show when in active state
                if (_nfcFabState == NfcFabState.active) ...List.generate(3, (index) {
                  final delay = index * 0.3; // Quicker succession
                  final progress = (_rippleWave.value - delay).clamp(0.0, 1.0);

                  // Smooth easing function for more natural animation
                  final easedProgress = Curves.easeOut.transform(progress);
                  final rippleSize = 110.0 + (easedProgress * 120.0); // Start closer to FAB size
                  final borderRadius = 20.0 + (easedProgress * 10.0); // Match FAB shape with slight growth

                  // More subtle fade out
                  final opacity = (1.0 - easedProgress) * 0.6;

                  if (opacity <= 0.0) return const SizedBox.shrink();

                  return Container(
                    key: Key('home_nfc_fab_ripple_$index'),
                    width: rippleSize,
                    height: rippleSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(
                        color: nfcColors['primary']!.withOpacity(opacity),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
                // Main FAB
                Container(
                  key: const Key('home_nfc_fab_main'),
                  width: 96, // 8px * 12
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [nfcColors['primary']!, nfcColors['secondary']!],
                    ),
                    borderRadius: BorderRadius.circular(20), // Smooth square corners
                    boxShadow: [
                      BoxShadow(
                        color: nfcColors['primary']!.withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: nfcColors['secondary']!.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    key: const Key('home_nfc_fab_material'),
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('home_nfc_fab_inkwell'),
                      onTap: _isNfcLoading ? () {
                        developer.log('FAB tapped but _isNfcLoading is true, ignoring tap', name: 'Home.NFC');
                      } : () {
                        developer.log('FAB tapped, calling _onNfcTap()', name: 'Home.NFC');
                        _onNfcTap();
                      },
                      onLongPress: _isNfcLoading ? null : () {
                        developer.log('FAB long-pressed, showing mode picker', name: 'Home.NFC');
                        HapticFeedback.mediumImpact();
                        _showModePicker();
                      },
                      borderRadius: BorderRadius.circular(20), // Match container radius
                      child: Center(
                        key: const Key('home_nfc_fab_center'),
                        child: _buildFabContent(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFabContent() {
    // Mode-specific icons
    final IconData modeIcon = _nfcMode == NfcMode.tagWrite
        ? CupertinoIcons.arrow_up_arrow_down_square
        : CupertinoIcons.radiowaves_right;

    // Special case: NFC disabled
    if (!_nfcAvailable) {
      return Icon(
        modeIcon,
        key: const Key('home_nfc_fab_disabled'),
        color: AppColors.textSecondary,  // Gray
        size: 56,
      );
    }

    // FIVE-STATE FAB SYSTEM
    switch (_nfcFabState) {
      case NfcFabState.inactive:
        // Dull white icon, no animations
        return Icon(
          modeIcon,
          key: const Key('home_nfc_fab_inactive'),
          color: Colors.white.withOpacity(0.5),  // Dull white
          size: 56,
        );

      case NfcFabState.active:
        // Glowing white icon with breathing animation, NO TEXT
        return ScaleTransition(
          key: const Key('home_nfc_fab_active'),
          scale: _pulseScale,
          child: Icon(
            modeIcon,
            color: Colors.white,  // Glowing white
            size: 56,
          ),
        );

      case NfcFabState.writing:
        // Loading spinner during NFC write
        return SizedBox(
          key: const Key('home_nfc_fab_writing'),
          width: 32,
          height: 32,
          child: CupertinoActivityIndicator(
            color: Colors.white,
            radius: 16,
          ),
        );

      case NfcFabState.success:
        // Green checkmark with pop animation
        return ScaleTransition(
          key: const Key('home_nfc_fab_success'),
          scale: _successScale,
          child: Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: Colors.greenAccent,
            size: 56,
          ),
        );

      case NfcFabState.error:
        // Red X icon
        return Icon(
          CupertinoIcons.exclamationmark_circle_fill,
          key: const Key('home_nfc_fab_error'),
          color: Colors.redAccent,
          size: 56,
        );
    }
  }

  Map<String, Color> _getNfcStateColors() {
    // Gray gradient ONLY for NFC disabled
    if (!_nfcAvailable) {
      return {
        'primary': Colors.grey.shade400,
        'secondary': Colors.grey.shade600,
      };
    }

    // State-based colors when NFC is available
    switch (_nfcFabState) {
      case NfcFabState.inactive:
      case NfcFabState.active:
      case NfcFabState.writing:
        // Mode-specific gradients
        if (_nfcMode == NfcMode.p2pShare) {
          // Purple gradient for P2P mode
          return {
            'primary': const Color(0xFF9C27B0),  // Material Purple 500
            'secondary': const Color(0xFF673AB7), // Material Deep Purple 500
          };
        } else {
          // Orange gradient for Tag Write mode (default)
          return {
            'primary': AppColors.primaryAction,
            'secondary': AppColors.secondaryAction,
          };
        }

      case NfcFabState.success:
        return {
          'primary': Colors.green.shade400,
          'secondary': Colors.green.shade600,
        };

      case NfcFabState.error:
        return {
          'primary': Colors.red.shade400,
          'secondary': Colors.red.shade600,
        };
    }
  }

  Widget _buildTapToShareText() {
    // Determine text and color based on state AND mode
    String text;
    Color textColor;

    if (!_nfcAvailable) {
      text = 'NFC not available';
      textColor = AppColors.textSecondary;
    } else {
      // Mode-specific text
      final isTagWrite = _nfcMode == NfcMode.tagWrite;

      switch (_nfcFabState) {
        case NfcFabState.inactive:
          text = isTagWrite
              ? 'Bring device close to share'
              : 'Hold & tap to switch modes';
          textColor = Colors.white.withOpacity(0.6);  // Dull white
          break;

        case NfcFabState.active:
          text = isTagWrite
              ? 'Tap to Share'
              : 'Ready for Tap';
          textColor = AppColors.primaryAction;  // Orange
          break;

        case NfcFabState.writing:
          // Writing state kept for compatibility but shows same as active
          text = isTagWrite
              ? 'Tap to Share'
              : 'Ready for Tap';
          textColor = AppColors.primaryAction;  // Orange
          break;

        case NfcFabState.success:
          text = isTagWrite
              ? 'Written successfully!'
              : 'Shared successfully!';
          textColor = Colors.greenAccent;
          break;

        case NfcFabState.error:
          text = isTagWrite
              ? 'Write failed'
              : 'Share failed';
          textColor = Colors.redAccent;
          break;
      }
    }

    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        return Column(
          key: const Key('home_tap_share_column'),
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              style: AppTextStyles.h3.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              child: Text(
                text,
                key: const Key('home_tap_share_title'),
              ),
            ),
        const SizedBox(key: Key('home_tap_share_spacing'), height: 24),
        Material(
          key: const Key('home_share_options_material'),
          color: Colors.transparent,
          child: InkWell(
            key: const Key('home_share_options_inkwell'),
            onTap: _showShareModal,
            borderRadius: BorderRadius.circular(20),
            child: ClipRRect(
              key: const Key('home_share_options_clip'),
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                key: const Key('home_share_options_backdrop'),
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  key: const Key('home_share_options_container'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    key: const Key('home_share_options_row'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.share,
                        key: const Key('home_share_options_icon'),
                        size: 20,
                        color: AppColors.primaryAction,
                      ),
                      const SizedBox(key: Key('home_share_options_text_spacing'), width: 10),
                      Text(
                        'More sharing options',
                        key: const Key('home_share_options_text'),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primaryAction,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
          ],
        );
      },
    );
  }

  Widget _buildCardPreview() {
    final activeProfile = _profileService.activeProfile;
    if (activeProfile == null) {
      return Container(
        key: const Key('home_card_preview_loading'),
        width: 300,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'No Profile Found',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Center(
      key: const Key('home_card_preview_container'),
      child: ProfileCardPreview(
        profile: activeProfile,
        width: 300,
        height: 180,
        borderRadius: 20,
        onEmailTap: activeProfile.email != null ? () => _launchEmail(activeProfile.email!) : null,
        onPhoneTap: activeProfile.phone != null ? () => _launchPhone(activeProfile.phone!) : null,
        onWebsiteTap: activeProfile.website != null ? () => _launchUrl(activeProfile.website!) : null,
        onSocialTap: (platform, url) => _launchSocialMedia(platform, url),
      ),
    );
  }

  Widget _buildPreviewText() {
    return Column(
      key: const Key('home_preview_text_column'),
      children: [
        Text(
          'Card Preview',
          key: const Key('home_preview_title'),
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(key: const Key('home_preview_subtitle_spacing'), height: 8),
        Text(
          'This is how your card will appear to others',
          key: const Key('home_preview_subtitle'),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecentContactsStrip() {
    return Column(
      key: const Key('contacts-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Recent Contacts',
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          key: const Key('contacts-list'),
          height: 88,
          child: _isContactsLoading
              ? _buildContactsLoading()
              : _recentContacts.isEmpty
                  ? _buildContactsEmpty()
                  : _buildContactsList(),
        ),
      ],
    );
  }

  Widget _buildContactsLoading() {
    return ListView.builder(
      key: const Key('home_contacts_loading_list'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16), // 8px * 2
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          key: Key('home_contacts_loading_item_$index'),
          width: 72, // 8px * 9
          margin: const EdgeInsets.only(right: 12),
          child: ClipRRect(
            key: Key('home_contacts_loading_clip_$index'),
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              key: Key('home_contacts_loading_backdrop_$index'),
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                key: Key('home_contacts_loading_container_$index'),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  key: Key('home_contacts_loading_column_$index'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      key: Key('home_contacts_loading_avatar_$index'),
                      width: 32, // 8px * 4
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(key: Key('home_contacts_loading_spacing'), height: 8),
                    Container(
                      key: Key('home_contacts_loading_name_$index'),
                      width: 40, // 8px * 5
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactsEmpty() {
    return Center(
      key: const Key('home_contacts_empty_center'),
      child: Column(
        key: const Key('home_contacts_empty_column'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.person_2,
            key: const Key('home_contacts_empty_icon'),
            color: AppColors.textTertiary,
            size: 24, // 8px * 3
          ),
          const SizedBox(key: Key('home_contacts_empty_spacing'), height: 8),
          Text(
            'No recent contacts',
            key: const Key('home_contacts_empty_text'),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return AnimatedBuilder(
      key: const Key('home_contacts_list_animated'),
      animation: _contactsController,
      builder: (context, child) {
        return Transform.translate(
          key: const Key('home_contacts_list_transform'),
          offset: Offset(0, _contactsSlide.value * 50),
          child: Opacity(
            key: const Key('home_contacts_list_opacity'),
            opacity: 1.0 - _contactsSlide.value,
            child: ListView.builder(
              key: const Key('home_contacts_list_view'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16), // 8px * 2
              itemCount: _recentContacts.length,
              itemBuilder: (context, index) {
                final contact = _recentContacts[index];
                return _buildContactCard(contact, index);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactCard(Contact contact, int index) {
    return Container(
      key: Key('home_contact_card_$index'),
      width: 72, // 8px * 9
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        key: Key('home_contact_clip_$index'),
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          key: Key('home_contact_backdrop_$index'),
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            key: Key('home_contact_container_$index'),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              key: Key('home_contact_material_$index'),
              color: Colors.transparent,
              child: InkWell(
                key: Key('home_contact_inkwell_$index'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  // TODO: Handle contact tap
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  key: Key('home_contact_padding_$index'),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    key: Key('home_contact_column_$index'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        contact.avatar,
                        key: Key('home_contact_avatar_$index'),
                        style: const TextStyle(fontSize: 24), // 8px * 3
                      ),
                      const SizedBox(key: Key('home_contact_avatar_spacing'), height: 4),
                      Text(
                        contact.name.split(' ').first,
                        key: Key('home_contact_name_$index'),
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        contact.lastShared,
                        key: Key('home_contact_last_shared_$index'),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10, // Smaller for secondary info
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentHistoryStrip() {
    return Column(
      key: const Key('home_history_strip'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: const Key('home_history_title_padding'),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                key: const Key('home_history_title'),
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.go(AppRoutes.history);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'View All',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryAction,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          key: const Key('home_history_list_container'),
          height: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<List<HistoryEntry>>(
            stream: HistoryService.historyStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildHistoryLoading();
              }

              if (snapshot.hasError) {
                return _buildHistoryEmpty();
              }

              final allHistory = snapshot.data ?? [];
              // Show only last 5 items
              final recentHistory = allHistory.take(5).toList();

              if (recentHistory.isEmpty) {
                return _buildHistoryEmpty();
              }

              return _buildHistoryList(recentHistory);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryLoading() {
    return ListView.builder(
      key: const Key('home_history_loading_list'),
      scrollDirection: Axis.vertical,
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          key: Key('home_history_loading_item_$index'),
          width: double.infinity,
          height: 60,
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryEmpty() {
    return Center(
      key: const Key('home_history_empty_center'),
      child: Column(
        key: const Key('home_history_empty_column'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.clock,
            key: const Key('home_history_empty_icon'),
            color: AppColors.textTertiary,
            size: 24,
          ),
          const SizedBox(key: Key('home_history_empty_spacing'), height: 8),
          Text(
            'No recent activity',
            key: const Key('home_history_empty_text'),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<HistoryEntry> history) {
    return ListView.builder(
      key: const Key('home_history_list_view'),
      scrollDirection: Axis.vertical,
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[index];
        return _buildHistoryCard(entry, index);
      },
    );
  }

  Widget _buildHistoryCard(HistoryEntry entry, int index) {
    final colors = _getHistoryColors(entry.type);
    final icon = _getHistoryIcon(entry.type);

    return Container(
      key: Key('home_history_card_$index'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        key: Key('home_history_clip_$index'),
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          key: Key('home_history_backdrop_$index'),
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            key: Key('home_history_container_$index'),
            decoration: BoxDecoration(
              color: colors['background'],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors['border']!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              key: Key('home_history_material_$index'),
              color: Colors.transparent,
              child: InkWell(
                key: Key('home_history_inkwell_$index'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go(AppRoutes.history);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  key: Key('home_history_padding_$index'),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    key: Key('home_history_row_$index'),
                    children: [
                      Container(
                        key: Key('home_history_icon_container_$index'),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors['iconBg'],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          key: Key('home_history_icon_$index'),
                          color: colors['icon'],
                          size: 16,
                        ),
                      ),
                      const SizedBox(key: Key('home_history_content_spacing'), width: 12),
                      Expanded(
                        key: Key('home_history_content_$index'),
                        child: Column(
                          key: Key('home_history_content_column_$index'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getHistoryTitle(entry.type),
                              key: Key('home_history_title_$index'),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              entry.displayName,
                              key: Key('home_history_name_$index'),
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              _formatHistoryTime(entry.timestamp),
                              key: Key('home_history_time_$index'),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      MethodChip(
                        method: entry.method,
                        fontSize: 9,
                        iconSize: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, Color> _getHistoryColors(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return {
          'background': AppColors.primaryAction.withOpacity(0.1),
          'border': AppColors.primaryAction.withOpacity(0.3),
          'iconBg': AppColors.primaryAction.withOpacity(0.2),
          'icon': AppColors.primaryAction,
          'text': AppColors.primaryAction,
        };
      case HistoryEntryType.received:
        return {
          'background': AppColors.success.withOpacity(0.1),
          'border': AppColors.success.withOpacity(0.3),
          'iconBg': AppColors.success.withOpacity(0.2),
          'icon': AppColors.success,
          'text': AppColors.success,
        };
      case HistoryEntryType.tag:
        return {
          'background': AppColors.secondaryAction.withOpacity(0.1),
          'border': AppColors.secondaryAction.withOpacity(0.3),
          'iconBg': AppColors.secondaryAction.withOpacity(0.2),
          'icon': AppColors.secondaryAction,
          'text': AppColors.secondaryAction,
        };
    }
  }

  IconData _getHistoryIcon(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return CupertinoIcons.arrow_up_circle_fill;
      case HistoryEntryType.received:
        return CupertinoIcons.arrow_down_circle_fill;
      case HistoryEntryType.tag:
        return CupertinoIcons.tag_fill;
    }
  }

  String _getHistoryTitle(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return 'SENT TO';
      case HistoryEntryType.received:
        return 'RECEIVED FROM';
      case HistoryEntryType.tag:
        return 'WROTE TO TAG';
    }
  }

  String _formatHistoryTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Contact model class
class Contact {
  final String name;
  final String avatar;
  final String lastShared;

  Contact({
    required this.name,
    required this.avatar,
    required this.lastShared,
  });
}