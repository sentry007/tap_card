import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:developer' as developer;

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/profile_service.dart';
import '../../services/nfc_service.dart';
import '../../services/nfc_discovery_service.dart';
import '../../services/nfc_settings_service.dart';
import '../../core/constants/routes.dart';
import '../../models/unified_models.dart';
import '../../services/history_service.dart';
import '../../services/contact_service.dart';
import '../../services/profile_performance_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/history/method_chip.dart';
import '../../widgets/home/nfc_fab_widget.dart';
import '../../widgets/home/recent_connections_widget.dart';
import '../../widgets/home/nfc_helpers.dart';
import '../../widgets/home/profile_preview_widget.dart';
import '../../widgets/tutorial/tutorial_keys.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fabController;
  late AnimationController _pulseController;
  late AnimationController _contactsController;
  late AnimationController _rippleController;
  late AnimationController _successController;
  late AnimationController _gradientController;

  late Animation<double> _fabScale;
  late Animation<double> _fabGlow;
  late Animation<double> _pulseScale;
  late Animation<double> _rippleWave;
  late Animation<double> _successScale;
  late Animation<double> _gradientAnimation;

  final bool _isNfcLoading = false;
  bool _isPreviewMode = false; // Toggle between share mode and preview mode
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();


  bool _nfcAvailable = false;
  bool _nfcDeviceDetected = false;

  // NFC FAB state
  NfcFabState _nfcFabState = NfcFabState.inactive;
  NfcMode _nfcMode = NfcMode.tagWrite; // Default to tag write mode
  late NotificationService _notificationService;
  late ProfileService _profileService;

  // NFC Performance Optimization: Pre-cached data for instant sharing
  ProfileData? _cachedActiveProfile; // Pre-cached active profile
  Map<String, String>?
      _cachedDualPayload; // Pre-cached dual-payload (vCard + URL)
  bool _isPayloadReady = false; // True when payload is cached and ready

  // State reset timer for success/error states
  Timer? _stateResetTimer;

  // Device contacts sync state
  bool _isSyncingContacts = false;

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
    developer.log('🔄 Refreshing NFC cache (screen resumed or data changed)',
        name: 'Home.NFC');
    _preCacheNfcPayload();
  }

  void _initServices() {
    _notificationService = NotificationService();
    _profileService = ProfileService();

    // Initialize services
    _initializeNFC();
    _initializeHistory();
    _loadNfcSettings();

    // Setup notification callback
    _notificationService.setCardReceivedCallback(_handleCardReceived);

    // NFC state changes handled in simplified service
  }

  /// Load NFC settings including default mode
  Future<void> _loadNfcSettings() async {
    await NfcSettingsService.initialize();
    final defaultMode = await NfcSettingsService.getDefaultMode();

    if (mounted) {
      setState(() {
        _nfcMode = defaultMode;
      });
      developer.log('⚙️ Loaded default NFC mode: ${defaultMode.name}',
          name: 'Home.Settings');
    }
  }

  Future<void> _initializeHistory() async {
    await HistoryService.initialize();
  }

  Future<void> _initializeNFC() async {
    _nfcAvailable = await NFCService.initialize();
    if (!_nfcAvailable) {
      NfcHelpers.showNfcSetupDialog(context, () {
        setState(() => _nfcAvailable = true);
      });
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
      duration: const Duration(
          milliseconds: 1200), // Faster and synchronized with ripple
      vsync: this,
    );

    _contactsController = AnimationController(
      duration: const Duration(milliseconds: 500), // Snappier
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(
          milliseconds: 1500), // Synchronized with pulse for organic feel
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

    // Gradient animation controller for flowing gradient effect
    _gradientController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _gradientAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gradientController,
      curve: Curves.linear,
    ));

    // Start the breathing pulse animation - key UX element
    _pulseController.repeat(reverse: true);

    // Start the gradient flow animation
    _gradientController.repeat();
  }

  Future<void> _loadContacts() async {
    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        // Contacts loaded
      });
      _contactsController.forward();
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await _loadContacts();
  }

  /// Sync device contacts to find TapCard URLs
  Future<void> _syncDeviceContacts() async {
    if (_isSyncingContacts) return;

    developer.log('📱 Starting device contacts sync', name: 'Home.ContactSync');

    setState(() => _isSyncingContacts = true);
    HapticFeedback.lightImpact();

    try {
      // Check permissions first
      final hasPermission = await ContactService.hasContactsPermission();

      if (!hasPermission) {
        // Request permission
        final status = await ContactService.requestContactsPermission();
        if (!status.isGranted) {
          developer.log('❌ Contacts permission denied',
              name: 'Home.ContactSync');
          if (mounted) {
            setState(() => _isSyncingContacts = false);
            _showPermissionDeniedSnackbar();
          }
          return;
        }
      }

      // Scan device contacts for TapCard URLs
      final tapCardContacts =
          await ContactService.scanForTapCardContactsWithIds();

      developer.log(
        '✅ Found ${tapCardContacts.length} TapCard contacts in device',
        name: 'Home.ContactSync',
      );

      // Save scanned contacts to history (if not already present)
      // This ensures they appear in "Recent Connections" on home screen
      if (tapCardContacts.isNotEmpty) {
        await _saveScannedContactsToHistory(tapCardContacts);
      }

      if (mounted) {
        setState(() {
          _isSyncingContacts = false;
        });

        // Show success feedback
        HapticFeedback.mediumImpact();
        _showSyncSuccessSnackbar(tapCardContacts.length);
      }
    } catch (e) {
      developer.log('❌ Contact sync failed: $e', name: 'Home.ContactSync');
      if (mounted) {
        setState(() => _isSyncingContacts = false);
        _showSyncErrorSnackbar();
      }
    }
  }

  void _showPermissionDeniedSnackbar() {
    SnackbarHelper.show(
      context,
      message: 'Contacts permission required to sync',
      type: SnackbarType.error,
      action: SnackBarAction(
        label: 'Settings',
        textColor: AppColors.textPrimary,
        onPressed: () => AppSettings.openAppSettings(),
      ),
    );
  }

  void _showSyncSuccessSnackbar(int count) {
    if (count > 0) {
      SnackbarHelper.showSuccess(
        context,
        message: 'Found $count Atlas Linq contact${count == 1 ? '' : 's'}',
        duration: const Duration(seconds: 3),
      );
    } else {
      SnackbarHelper.showInfo(
        context,
        message: 'No Atlas Linq contacts found in device',
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _showSyncErrorSnackbar() {
    SnackbarHelper.showError(
      context,
      message: 'Failed to sync contacts. Please try again.',
    );
  }

  /// Save scanned contacts to history
  ///
  /// This ensures scanned contacts appear in "Recent Connections".
  /// Only saves contacts that aren't already in the history to avoid duplicates.
  Future<void> _saveScannedContactsToHistory(List<TapCardContact> contacts) async {
    try {
      developer.log(
        '💾 Saving ${contacts.length} scanned contacts to history',
        name: 'Home.ContactSync',
      );

      // Get existing history entries to avoid duplicates
      final existingEntries = await HistoryService.getAllHistory();
      final existingProfileIds = existingEntries
          .where((e) => e.type == HistoryEntryType.received && e.senderProfile != null)
          .map((e) => e.senderProfile!.id)
          .toSet();

      int savedCount = 0;
      for (final contact in contacts) {
        // Skip if already in history (check by profile ID)
        if (existingProfileIds.contains(contact.profileId)) {
          developer.log(
            '  ⏭️ Skipping ${contact.displayName} - already in history',
            name: 'Home.ContactSync',
          );
          continue;
        }

        // Create history entry from contact (with Firestore fetch)
        final entry = await HistoryService.createReceivedEntryFromContact(
          contact: contact,
        );

        // Add to history using the proper service method
        await HistoryService.addReceivedEntry(
          senderProfile: entry.senderProfile!,
          method: entry.method,
          location: entry.location,
          metadata: entry.metadata,
        );

        savedCount++;
        developer.log(
          '  ✅ Saved ${contact.displayName} to history',
          name: 'Home.ContactSync',
        );
      }

      developer.log(
        '✅ Saved $savedCount/${contacts.length} new contacts to history',
        name: 'Home.ContactSync',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to save contacts to history: $e',
        name: 'Home.ContactSync',
        error: e,
      );
    }
  }

  void _onNfcTap() async {
    developer.log('🔥 FAB button tapped - _onNfcTap() called',
        name: 'Home.NFC');
    developer.log(
        '   Current mode: ${_nfcMode == NfcMode.tagWrite ? "Tag Write" : "P2P Share"}',
        name: 'Home.NFC');
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
          color: AppColors.surfaceDark.withValues(alpha: 0.95),
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
                  color: AppColors.surfaceDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.glassBorder.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _buildModeOption(
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
                    _buildModeOption(
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
                          NfcHelpers.showErrorMessage(
                              context, 'Phone-to-Phone mode not supported on this device');
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

  Widget _buildModeOption({
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
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.surfaceMedium.withValues(alpha: 0.3),
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
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
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

    final modeName =
        newMode == NfcMode.tagWrite ? 'Tag Write' : 'Phone-to-Phone';
    NfcHelpers.showInfoMessage(context, 'Switched to $modeName mode');
  }

  /// Activate NFC write mode - FAB goes to "active" state
  Future<void> _activateNfcWriteMode() async {
    developer.log('🔥 Activating NFC write mode', name: 'Home.NFC');
    _fabController.forward().then((_) => _fabController.reverse());

    developer.log(
        '🔍 Checking NFC availability - _nfcAvailable: $_nfcAvailable',
        name: 'Home.NFC');
    if (!_nfcAvailable) {
      developer.log('❌ NFC not available, showing setup dialog',
          name: 'Home.NFC');
      NfcHelpers.showNfcSetupDialog(context, () {
        setState(() => _nfcAvailable = true);
      });
      return;
    }

    // ⚡ PERFORMANCE: Check if dual-payload is cached and ready (INSTANT check)
    developer.log(
        '🔍 Checking cached dual-payload - _isPayloadReady: $_isPayloadReady',
        name: 'Home.NFC');
    if (!_isPayloadReady || _cachedDualPayload == null) {
      developer.log('⚠️ Dual-payload not ready, attempting to cache now...',
          name: 'Home.NFC');
      NfcHelpers.showErrorMessage(context,'Profile not ready. Please wait a moment...');
      await _preCacheNfcPayload(); // Try to cache now
      if (!_isPayloadReady || _cachedDualPayload == null) {
        return;
      }
    }

    developer.log(
        '✅ Using cached DUAL-PAYLOAD (INSTANT - 0ms lag!)\n'
        '   • vCard: ${_cachedDualPayload!['vcard']!.length} bytes\n'
        '   • URL: ${_cachedDualPayload!['url']!.length} bytes',
        name: 'Home.NFC');

    // CRITICAL: Pause NFC discovery service to prevent session conflicts
    developer.log('⏸️ Pausing NFC discovery service before write...',
        name: 'Home.NFC');
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
      developer.log('🚀 Generating payload with share context...',
          name: 'Home.NFC');
      final startTime = DateTime.now();

      // Create share context with current timestamp
      final shareContext = ShareContext(
        method: ShareMethod.nfc,
        timestamp: DateTime.now(),
      );

      // Generate fresh payload WITH metadata (adds ~40 bytes)
      final payload =
          _cachedActiveProfile!.getDualPayloadWithContext(shareContext);

      // Stay in ACTIVE state (breathing + ripples) until write completes
      // Writes are instant once tag is detected, so no loading state needed
      final result = await NFCService.writeData(payload);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log('⏱️ NFC operation completed in ${duration}ms',
          name: 'Home.NFC');
      developer.log('📊 NFCService returned: ${result.toString()}',
          name: 'Home.NFC');

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

          // Show appropriate message based on payload type
          final String message = result.payloadType == 'dual'
              ? 'Contact card written (with URL fallback)! 📇'
              : 'Web card written! 🌐';
          NfcHelpers.showSuccessMessage(context,message);
          _scheduleStateReset(duration: const Duration(seconds: 2));

          // Add to history with actual tag metadata from hardware
          _addNfcWriteToHistory(result);
        } else {
          // ERROR state - instant transition from active
          setState(() {
            _nfcFabState = NfcFabState.error;
          });
          if (result.error == 'Timeout') {
            NfcHelpers.showErrorMessage(context,
                'No NFC tag detected. Bring tag within 4cm and try again.');
          } else {
            NfcHelpers.showErrorMessage(context,'NFC write failed: ${result.error}');
          }
          _scheduleStateReset(duration: const Duration(seconds: 3));
        }
      }
    } catch (e) {
      developer.log('❌ Exception in _activateNfcWriteMode(): $e',
          name: 'Home.NFC', error: e);
      if (mounted) {
        setState(() {
          _nfcFabState = NfcFabState.error;
        });
        NfcHelpers.showErrorMessage(context,'Failed to activate NFC: $e');
        _scheduleStateReset(duration: const Duration(seconds: 3));
      }
    } finally {
      // CRITICAL: Always resume discovery service, even on errors
      developer.log('▶️ Resuming NFC discovery service after write...',
          name: 'Home.NFC');
      NFCDiscoveryService.resumeDiscovery();
    }
  }

  /// Deactivate NFC write mode - Cancel operation
  Future<void> _deactivateNfcWriteMode() async {
    developer.log('🔥 Deactivating NFC write mode (user cancelled)',
        name: 'Home.NFC');
    HapticFeedback.lightImpact();

    // Call native to cancel write mode
    try {
      await NFCService.cancelSession();
    } catch (e) {
      developer.log('⚠️ Failed to cancel NFC session: $e',
          name: 'Home.NFC', error: e);
    }

    if (mounted) {
      setState(() {
        _nfcFabState = NfcFabState.inactive;
      });
      _pulseController.stop();
      _rippleController.stop();
      _pulseController.reset();
      _rippleController.reset();
      NfcHelpers.showInfoMessage(context,'NFC write cancelled');
    }

    // Resume NFC discovery service after cancellation
    developer.log('▶️ Resuming NFC discovery service after cancellation...',
        name: 'Home.NFC');
    NFCDiscoveryService.resumeDiscovery();
  }

  /// Activate P2P mode - Phone acts as NFC tag via HCE
  Future<void> _activateP2pMode() async {
    developer.log('🔥 Activating P2P Share mode (HCE)', name: 'Home.P2P');
    _fabController.forward().then((_) => _fabController.reverse());

    developer.log(
        '🔍 Checking HCE availability - isHceSupported: ${NFCService.isHceSupported}',
        name: 'Home.P2P');
    if (!NFCService.isHceSupported) {
      developer.log('❌ HCE not supported on this device', name: 'Home.P2P');
      NfcHelpers.showErrorMessage(context,'Phone-to-Phone mode not supported on this device');
      return;
    }

    // Check if dual-payload is ready
    developer.log(
        '🔍 Checking cached dual-payload - _isPayloadReady: $_isPayloadReady',
        name: 'Home.P2P');
    if (!_isPayloadReady || _cachedDualPayload == null) {
      developer.log('⚠️ Dual-payload not ready, attempting to cache now...',
          name: 'Home.P2P');
      NfcHelpers.showErrorMessage(context,'Profile not ready. Please wait a moment...');
      await _preCacheNfcPayload();
      if (!_isPayloadReady || _cachedDualPayload == null) {
        return;
      }
    }

    developer.log(
        '✅ Using cached DUAL-PAYLOAD for P2P (INSTANT - 0ms lag!)\n'
        '   • vCard: ${_cachedDualPayload!['vcard']!.length} bytes\n'
        '   • URL: ${_cachedDualPayload!['url']!.length} bytes',
        name: 'Home.P2P');

    // CRITICAL: Pause NFC discovery service to prevent conflicts
    developer.log('⏸️ Pausing NFC discovery service before HCE...',
        name: 'Home.P2P');
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
          name: 'Home.P2P');
      final startTime = DateTime.now();

      // For P2P/HCE, use dual-payload for universal compatibility
      // Android phones save vCard contact, iPhone opens URL as fallback
      final vCardPayload = _cachedDualPayload!['vcard']!;
      final urlPayload = _cachedDualPayload!['url']!;

      developer.log(
          '📦 P2P dual-payload ready\n'
          '   • vCard: ${vCardPayload.length} bytes\n'
          '   • URL: $urlPayload\n'
          '   • Android → Saves vCard | iPhone → Opens URL',
          name: 'Home.P2P');

      final result =
          await NFCService.startCardEmulation(vCardPayload, urlPayload);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log('⏱️ P2P operation completed in ${duration}ms',
          name: 'Home.P2P');
      developer.log('📊 NFCService returned: ${result.toString()}',
          name: 'Home.P2P');

      if (mounted) {
        if (result.isSuccess) {
          // Keep in ACTIVE state - HCE is now running and waiting for tap
          developer.log(
              '✅ P2P mode activated successfully\n'
              '   📲 Your phone is now acting as an NFC tag\n'
              '   👉 Other phones can tap to receive your card\n'
              '   🔹 Status: ACTIVE and waiting\n'
              '   🔹 Tap FAB again to stop sharing',
              name: 'Home.P2P');
          NfcHelpers.showSuccessMessage(context,'Ready! Hold phones together to share');

          // Add P2P share to history
          _addP2pShareToHistory();
        } else {
          // ERROR state
          _pulseController.stop();
          _rippleController.stop();
          setState(() {
            _nfcFabState = NfcFabState.error;
          });
          developer.log('❌ Failed to start P2P mode: ${result.error}',
              name: 'Home.P2P');
          NfcHelpers.showErrorMessage(context,'Failed to start P2P mode: ${result.error}');
          _scheduleStateReset(duration: const Duration(seconds: 3));
        }
      }
    } catch (e, stackTrace) {
      developer.log('❌ Exception in _activateP2pMode(): $e',
          name: 'Home.P2P', error: e, stackTrace: stackTrace);
      if (mounted) {
        _pulseController.stop();
        _rippleController.stop();
        setState(() {
          _nfcFabState = NfcFabState.error;
        });
        NfcHelpers.showErrorMessage(context,'Failed to activate P2P: $e');
        _scheduleStateReset(duration: const Duration(seconds: 3));
      }
    } finally {
      // Note: DON'T resume discovery service here - keep it paused while HCE is active
      developer.log(
          'ℹ️ Discovery service remains paused while P2P mode is active',
          name: 'Home.P2P');
    }
  }

  /// Deactivate P2P mode - Stop HCE
  Future<void> _deactivateP2pMode() async {
    developer.log('🔥 Deactivating P2P mode (user cancelled or completed)',
        name: 'Home.P2P');
    HapticFeedback.lightImpact();

    // Stop HCE card emulation
    try {
      developer.log('🛑 Calling NFCService.stopCardEmulation()...',
          name: 'Home.P2P');
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
      NfcHelpers.showInfoMessage(context,'P2P sharing stopped');
    }

    // Resume NFC discovery service after deactivation
    developer.log('▶️ Resuming NFC discovery service after P2P deactivation...',
        name: 'Home.P2P');
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
      NfcHelpers.showErrorMessage(context,'Profile not ready. Please wait...');
      _preCacheNfcPayload();
      return;
    }

    ShareModal.show(
      context,
      userName: _cachedActiveProfile!.name,
      userEmail: _cachedActiveProfile!.email ?? '',
      profileImageUrl: _cachedActiveProfile!.profileImagePath,
      profile:
          _cachedActiveProfile!, // Pass full profile for metadata generation
      onNFCShare: _onNfcTap,
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
      developer.log('⚡ Pre-caching DUAL-PAYLOAD for instant NFC sharing...',
          name: 'Home.NFC');
      final startTime = DateTime.now();

      // Get active profile (synchronous from service)
      final profile = await _getActiveProfileForSharing();

      if (profile == null) {
        developer.log('⚠️ No active profile found for caching',
            name: 'Home.NFC');
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
          name: 'Home.NFC');

      if (mounted) {
        setState(() {
          _cachedActiveProfile = profile;
          _cachedDualPayload = dualPayload;
          _isPayloadReady = true;
        });
      }
    } catch (e) {
      developer.log('❌ Error pre-caching dual-payload: $e',
          name: 'Home.NFC', error: e);
      if (mounted) {
        setState(() {
          _cachedActiveProfile = null;
          _cachedDualPayload = null;
          _isPayloadReady = false;
        });
      }
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
        developer.log('Location permission denied forever',
            name: 'Home.Location');
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
            place.locality, // City
            place.administrativeArea // State/Province
          ].where((e) => e != null && e.isNotEmpty).toList();

          if (locationParts.isNotEmpty) {
            final location = locationParts.join(', ');
            developer.log('📍 Location: $location', name: 'Home.Location');
            return location;
          }
        }

        developer.log('⚠️ Reverse geocoding returned no placemarks',
            name: 'Home.Location');
      } catch (geocodeError) {
        developer.log('⚠️ Reverse geocoding failed, using coordinates',
            name: 'Home.Location', error: geocodeError);
      }

      // Fallback to coordinates if reverse geocoding fails
      final location =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      developer.log('📍 Location (coordinates): $location',
          name: 'Home.Location');
      return location;
    } catch (e) {
      developer.log('Failed to get location: $e',
          name: 'Home.Location', error: e);
      return null;
    }
  }

  /// Add NFC tag write to history with actual tag metadata from hardware
  Future<void> _addNfcWriteToHistory(NFCResult result) async {
    try {
      final location = await _getCurrentLocation();

      // Use actual tag data from NFCResult, with fallbacks
      final tagId =
          result.tagId ?? 'TAG_${DateTime.now().millisecondsSinceEpoch}';
      final tagCapacity = result.tagCapacity;
      final tagType = _inferTagTypeFromCapacity(tagCapacity);
      final payloadType = result.payloadType; // "dual" or "url"

      await HistoryService.addTagEntry(
        profileName: _profileService.activeProfile?.name ?? 'Unknown Profile',
        profileType: _profileService.activeProfile?.type ?? ProfileType.personal,
        tagId: tagId,
        tagType: tagType,
        method: ShareMethod.tag,
        tagCapacity: tagCapacity,
        payloadType: payloadType,
        location: location,
      );

      final locationStr = location != null ? ' at $location' : '';
      final capacityStr = tagCapacity != null ? ' ($tagCapacity bytes)' : '';
      final payloadStr = payloadType != null
          ? ' [${payloadType == "dual" ? "Full card" : "Mini card"}]'
          : '';
      developer.log(
          '✅ NFC write added to history: $tagId ($tagType$capacityStr)$payloadStr$locationStr',
          name: 'Home.History');
    } catch (e) {
      developer.log('❌ Error adding NFC write to history: $e',
          name: 'Home.History', error: e);
    }
  }

  /// Add P2P share to history
  Future<void> _addP2pShareToHistory() async {
    try {
      final location = await _getCurrentLocation();

      await HistoryService.addSentEntry(
        recipientName: _cachedActiveProfile != null
            ? 'P2P ${_cachedActiveProfile!.type.label} Card'
            : 'P2P Card',
        method: ShareMethod.nfc,
        location: location,
        metadata: {
          'mode': 'p2p_hce',
          'activationTime': DateTime.now().toIso8601String(),
        },
      );

      final locationStr = location != null ? ' at $location' : '';
      developer.log('✅ P2P share added to history$locationStr',
          name: 'Home.History');
    } catch (e) {
      developer.log('❌ Error adding P2P share to history: $e',
          name: 'Home.History', error: e);
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


  @override
  void dispose() {
    // Cancel state reset timer
    _stateResetTimer?.cancel();

    // Stop P2P emulation if active
    if (_nfcMode == NfcMode.p2pShare && _nfcFabState == NfcFabState.active) {
      developer.log('🛑 Stopping P2P emulation (leaving page)',
          name: 'Home.P2P');
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
    _gradientController.dispose();

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
                  SizedBox(
                      height: statusBarHeight +
                          80  + 20
                          ), // App bar space + original spacing
                  // 1) Quick Insights card at the top
                  _buildInsightsSection(),
                  const SizedBox(height: 32),
                  // 2) NFC share area (FAB + status/share options)
                  _isPreviewMode ? ProfilePreviewWidget(profileService: _profileService) : _buildHeroNfcFab(),
                  const SizedBox(height: 16),
                  _isPreviewMode ? const ProfilePreviewTextWidget() : _buildTapToShareText(),
                  const SizedBox(height: 24),
                  // 3) Unified Recent Activity (connections + activity)
                  _buildRecentHistoryStrip(),
                  const SizedBox(height: 24),
                  // 4) Frequent contacts
                  _buildFrequentContactsSection(),
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
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
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
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Image.asset(
                            'assets/images/atlaslinq_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AtlasLinq',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _buildAppBarIcon(
                        CupertinoIcons.settings, _onSettingsTap, 'settings'),
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
            _isPreviewMode
                ? CupertinoIcons.antenna_radiowaves_left_right
                : CupertinoIcons.eye,
            key: const Key('home_mode_toggle_icon'),
            color: _isPreviewMode
                ? AppColors.primaryAction
                : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroNfcFab() {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_fabController, _pulseController, _rippleController, _successController, _gradientController]),
      builder: (context, child) {
        return NfcFabWidget(
          tutorialKey: TutorialKeys.homeNfcFabKey,  // Separate parameter to target the visible FAB
          state: _nfcFabState,
          mode: _nfcMode,
          nfcAvailable: _nfcAvailable,
          nfcDeviceDetected: _nfcDeviceDetected,
          isLoading: _isNfcLoading,
          onTap: () {
            developer.log('FAB tapped, calling _onNfcTap()',
                name: 'Home.NFC');
            _onNfcTap();
          },
          onLongPress: () {
            developer.log('FAB long-pressed, showing mode picker',
                name: 'Home.NFC');
            HapticFeedback.mediumImpact();
            _showModePicker();
          },
          fabScale: _fabScale,
          fabGlow: _fabGlow,
          pulseScale: _pulseScale,
          rippleWave: _rippleWave,
          successScale: _successScale,
          gradientAnimation: _gradientAnimation,
        );
      },
    );
  }

  Widget _buildTapToShareText() {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        return Column(
          key: const Key('home_tap_share_column'),
          children: [
            NfcFabStatusText(
              key: TutorialKeys.homeModeIndicatorKey,
              state: _nfcFabState,
              mode: _nfcMode,
              nfcAvailable: _nfcAvailable,
            ),
            const SizedBox(key: Key('home_tap_share_spacing'), height: 24),
            ShareOptionsButton(
              key: TutorialKeys.homeShareOptionsKey,
              onTap: _showShareModal,
            ),
          ],
        );
      },
    );
  }


  Widget _buildInitialsCircle(String initials, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.body.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'
        .toUpperCase();
  }

  Widget _buildFrequentContactsSection() {
    return StreamBuilder<List<HistoryEntry>>(
      stream: HistoryService.historyStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final allHistory = snapshot.data!;

        // Count frequency of each contact based on received entries
        final frequencyMap = <String, FrequentContactData>{};

        for (final entry in allHistory) {
          if (entry.type == HistoryEntryType.received &&
              entry.senderProfile != null) {
            final name = entry.senderProfile!.name;
            if (frequencyMap.containsKey(name)) {
              frequencyMap[name]!.count++;
              // Keep the most recent entry
              if (entry.timestamp
                  .isAfter(frequencyMap[name]!.lastEntry.timestamp)) {
                frequencyMap[name]!.lastEntry = entry;
              }
            } else {
              frequencyMap[name] = FrequentContactData(
                lastEntry: entry,
                count: 1,
              );
            }
          }
        }

        // Filter contacts with at least 2 interactions and sort by frequency
        final frequentContacts = frequencyMap.values
            .where((data) => data.count >= 2)
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));

        // Show nothing if no frequent contacts
        if (frequentContacts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Take top 5
        final topContacts = frequentContacts.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Frequent Contacts',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryAction.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${topContacts.length}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.secondaryAction,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Sync device contacts button
                  GestureDetector(
                    onTap: _isSyncingContacts ? null : _syncDeviceContacts,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.info.withValues(alpha: 0.2),
                            AppColors.info.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSyncingContacts)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.info),
                              ),
                            )
                          else
                            const Icon(
                              Icons.sync,
                              size: 14,
                              color: AppColors.info,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            _isSyncingContacts ? 'Syncing...' : 'Sync',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'People you interact with most',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 88,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: topContacts.length,
                itemBuilder: (context, index) {
                  final data = topContacts[index];
                  return _buildFrequentContactCard(data, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFrequentContactCard(FrequentContactData data, int index) {
    final entry = data.lastEntry;
    final profile = entry.senderProfile!;
    final hasImage = profile.profileImagePath != null &&
        profile.profileImagePath!.isNotEmpty;
    final initials = _getInitials(profile.name);

    return Container(
      key: Key('frequent_contact_card_$index'),
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.secondaryAction.withValues(alpha: 0.15),
                  AppColors.secondaryAction.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondaryAction.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('${AppRoutes.history}?entryId=${entry.id}');
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile picture or initials with count badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          hasImage
                              ? Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.secondaryAction,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.network(
                                      profile.profileImagePath!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return _buildInitialsCircle(
                                          initials,
                                          AppColors.secondaryAction,
                                        );
                                      },
                                    ),
                                  ),
                                )
                              : _buildInitialsCircle(
                                  initials, AppColors.secondaryAction),
                          // Frequency badge
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryAction,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryBackground,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${data.count}',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Name (first name only)
                      Text(
                        profile.name.split(' ').first,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
        // Section header with "View All" button
        Padding(
          key: const Key('home_history_title_padding'),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeaderWithInfo(
                key: Key('home_history_title'),
                title: 'Recent Activity',
                infoText: 'Your recent connections and sharing activity. Top row shows people who shared with you, bottom section shows your NFC activity (sent & tags).',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        const SizedBox(height: 12),
        // Unified activity view with StreamBuilder
        StreamBuilder<List<HistoryEntry>>(
          stream: HistoryService.historyStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildUnifiedActivityLoading();
            }

            if (snapshot.hasError) {
              return _buildUnifiedActivityEmpty();
            }

            final allHistory = snapshot.data ?? [];

            // Split into received (connections) and sent/tag (activity)
            final received = allHistory
                .where((e) => e.type == HistoryEntryType.received && e.senderProfile != null)
                .take(10)
                .toList();

            final sentAndTags = allHistory
                .where((e) => e.type == HistoryEntryType.sent || e.type == HistoryEntryType.tag)
                .take(5)
                .toList();

            if (received.isEmpty && sentAndTags.isEmpty) {
              return _buildUnifiedActivityEmpty();
            }

            return _buildUnifiedActivity(received, sentAndTags);
          },
        ),
      ],
    );
  }

  /// Build unified activity view with received (horizontal) and sent/tags (vertical)
  Widget _buildUnifiedActivity(List<HistoryEntry> received, List<HistoryEntry> sentAndTags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal scrollable connections (received cards)
        if (received.isNotEmpty) ...[
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: received.length,
              itemBuilder: (context, index) {
                final entry = received[index];
                return ConnectionCard(entry: entry, index: index);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Vertical list of sent/tag activity
        if (sentAndTags.isNotEmpty) ...[
          Container(
            height: 280,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              itemCount: sentAndTags.length,
              itemBuilder: (context, index) {
                final entry = sentAndTags[index];
                return _buildHistoryCard(entry, index);
              },
            ),
          ),
        ],
        // Show empty state if no sent/tags but have received
        if (sentAndTags.isEmpty && received.isNotEmpty) ...[
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.arrow_up_circle,
                    color: AppColors.textTertiary,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No sharing activity yet',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Tap the NFC button above to share',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Loading state for unified activity
  Widget _buildUnifiedActivityLoading() {
    return Column(
      children: [
        // Horizontal loading
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 72,
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Vertical loading
        Container(
          height: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                width: double.infinity,
                height: 60,
                margin: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Empty state for unified activity
  Widget _buildUnifiedActivityEmpty() {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.clock,
              color: AppColors.textTertiary,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'No activity yet',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start sharing or receiving cards to see activity',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary.withValues(alpha: 0.7),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(HistoryEntry entry, int index) {
    final colors = _getHistoryColors(entry.type);
    final icon = _getHistoryIcon(entry.type);
    final isNew = DateTime.now().difference(entry.timestamp).inHours < 24;
    final isReceived = entry.type == HistoryEntryType.received;
    final hasProfileImage = isReceived &&
        entry.senderProfile?.profileImagePath != null &&
        entry.senderProfile!.profileImagePath!.isNotEmpty;

    return Container(
      key: Key('home_history_card_$index'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        key: Key('home_history_clip_$index'),
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          key: Key('home_history_backdrop_$index'),
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            key: Key('home_history_container_$index'),
            decoration: BoxDecoration(
              color: colors['background'],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors['border']!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
                  context.go('${AppRoutes.history}?entryId=${entry.id}');
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  key: Key('home_history_padding_$index'),
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    key: Key('home_history_row_$index'),
                    children: [
                      // Profile Image or Icon
                      hasProfileImage
                          ? Container(
                              key: Key('home_history_avatar_$index'),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colors['icon']!,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16.5),
                                child: Image.network(
                                  entry.senderProfile!.profileImagePath!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildInitialsAvatar(
                                      entry.displayName,
                                      colors['icon']!,
                                    );
                                  },
                                ),
                              ),
                            )
                          : Container(
                              key: Key('home_history_icon_container_$index'),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors['iconBg'],
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                icon,
                                key: Key('home_history_icon_$index'),
                                color: colors['icon'],
                                size: 18,
                              ),
                            ),
                      const SizedBox(
                          key: Key('home_history_content_spacing'), width: 10),
                      Expanded(
                        key: Key('home_history_content_$index'),
                        child: Column(
                          key: Key('home_history_content_column_$index'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    entry.displayName,
                                    key: Key('home_history_name_$index'),
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (isNew) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryAction,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      'NEW',
                                      style: AppTextStyles.overline.copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: 7,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
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
                      const SizedBox(width: 6),
                      MethodChip(
                        method: entry.method,
                        fontSize: 8,
                        iconSize: 9,
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

  Widget _buildInitialsAvatar(String name, Color color) {
    final initials = name.isNotEmpty
        ? name.split(' ').take(2).map((n) => n[0].toUpperCase()).join()
        : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.7),
            color,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsSection() {
    return StreamBuilder<List<HistoryEntry>>(
      stream: HistoryService.historyStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return _buildActivityInsights(snapshot.data!);
      },
    );
  }

  Widget _buildActivityInsights(List<HistoryEntry> history) {
    // Calculate insights from last 7 days
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentHistory =
        history.where((e) => e.timestamp.isAfter(sevenDaysAgo)).toList();

    final receivedCount =
        recentHistory.where((e) => e.type == HistoryEntryType.received).length;
    final sentCount =
        recentHistory.where((e) => e.type == HistoryEntryType.sent).length;
    final newContacts = recentHistory
        .where((e) =>
            e.type == HistoryEntryType.received &&
            now.difference(e.timestamp).inHours < 24)
        .length;

    // Show empty state if no recent activity
    final hasRecentActivity = recentHistory.isNotEmpty;

    // Get profile service for view counts
    final profileService = ProfileService();
    final profiles = profileService.profiles;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(AppRoutes.insights);
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryAction.withValues(alpha: 0.08),
              AppColors.secondaryAction.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryAction.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: hasRecentActivity
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildInsightStat(
                          sentCount.toString(),
                          'Sent',
                          CupertinoIcons.arrow_up_circle_fill,
                          AppColors.primaryAction,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      Expanded(
                        child: _buildInsightStat(
                          receivedCount.toString(),
                          'Received',
                          CupertinoIcons.arrow_down_circle_fill,
                          AppColors.success,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      Expanded(
                        child: _buildInsightStat(
                          newContacts.toString(),
                          'New',
                          CupertinoIcons.sparkles,
                          AppColors.info,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      Expanded(
                        child: FutureBuilder<int>(
                          future: profiles.isEmpty
                              ? Future.value(0)
                              : ProfilePerformanceService.getTotalViewCount(profiles),
                          builder: (context, snapshot) {
                            final viewCount = snapshot.hasData ? snapshot.data! : 0;
                            return _buildInsightStat(
                              viewCount.toString(),
                              'Views',
                              CupertinoIcons.eye_fill,
                              AppColors.highlight,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Hint Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.chart_bar_alt_fill,
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap for detailed analytics',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Icon(
                    CupertinoIcons.chart_bar,
                    size: 40,
                    color: AppColors.textTertiary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start sharing with Atlas Linq to see insights!',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.arrow_right_circle,
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to explore',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
      ),
    );
  }

  Widget _buildInsightStat(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Map<String, Color> _getHistoryColors(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return {
          'background': AppColors.primaryAction.withValues(alpha: 0.1),
          'border': AppColors.primaryAction.withValues(alpha: 0.3),
          'iconBg': AppColors.primaryAction.withValues(alpha: 0.2),
          'icon': AppColors.primaryAction,
          'text': AppColors.primaryAction,
        };
      case HistoryEntryType.received:
        return {
          'background': AppColors.success.withValues(alpha: 0.1),
          'border': AppColors.success.withValues(alpha: 0.3),
          'iconBg': AppColors.success.withValues(alpha: 0.2),
          'icon': AppColors.success,
          'text': AppColors.success,
        };
      case HistoryEntryType.tag:
        return {
          'background': AppColors.secondaryAction.withValues(alpha: 0.1),
          'border': AppColors.secondaryAction.withValues(alpha: 0.3),
          'iconBg': AppColors.secondaryAction.withValues(alpha: 0.2),
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

// Helper class for tracking frequent contacts
class FrequentContactData {
  HistoryEntry lastEntry;
  int count;

  FrequentContactData({
    required this.lastEntry,
    required this.count,
  });
}
