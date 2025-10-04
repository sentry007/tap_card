import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
import '../../core/constants/routes.dart';
import '../../models/unified_models.dart';

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
  late NotificationService _notificationService;
  late ProfileService _profileService;
  late TokenManagerService _tokenManager;

  // NFC Performance Optimization: Pre-cached data for instant sharing
  ProfileData? _cachedActiveProfile;  // Pre-cached active profile
  String? _cachedNfcPayload;          // Pre-cached JSON payload
  bool _isPayloadReady = false;       // True when payload is cached and ready

  // State reset timer for success/error states
  Timer? _stateResetTimer;

  // Mock recent contacts data
  List<Contact> _recentContacts = [];

  // Mock recent history data
  List<HistoryActivity> _recentHistory = [];

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

    // Setup notification callback
    _notificationService.setCardReceivedCallback(_handleCardReceived);

    // NFC state changes handled in simplified service

    // Clean up expired tokens on app start
    _tokenManager.cleanupExpiredTokens();
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
        _recentHistory = _generateMockHistory();
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

  List<HistoryActivity> _generateMockHistory() {
    return [
      HistoryActivity(
        type: HistoryType.sent,
        contactName: 'John Williams',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        method: 'NFC',
      ),
      HistoryActivity(
        type: HistoryType.received,
        contactName: 'Maria Garcia',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        method: 'QR Code',
      ),
      HistoryActivity(
        type: HistoryType.qr,
        contactName: 'QR Scan',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        method: 'Camera',
      ),
      HistoryActivity(
        type: HistoryType.sent,
        contactName: 'Alex Thompson',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        method: 'NFC',
      ),
    ];
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await _loadContacts();
  }

  void _onNfcTap() async {
    developer.log('🔥 FAB button tapped - _onNfcTap() called', name: 'Home.NFC');
    HapticFeedback.mediumImpact();

    // Two-state FAB system: Toggle between inactive and active
    if (_nfcFabState == NfcFabState.inactive) {
      // ACTIVATE NFC write mode
      await _activateNfcWriteMode();
    } else {
      // DEACTIVATE/CANCEL NFC write mode
      await _deactivateNfcWriteMode();
    }
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

    // ⚡ PERFORMANCE: Check if payload is cached and ready (INSTANT check)
    developer.log('🔍 Checking cached payload - _isPayloadReady: $_isPayloadReady', name: 'Home.NFC');
    if (!_isPayloadReady || _cachedNfcPayload == null) {
      developer.log('⚠️ Payload not ready, attempting to cache now...', name: 'Home.NFC');
      _showErrorMessage('Profile not ready. Please wait a moment...');
      await _preCacheNfcPayload(); // Try to cache now
      if (!_isPayloadReady || _cachedNfcPayload == null) {
        return;
      }
    }

    developer.log('✅ Using cached payload (INSTANT) - ${_cachedNfcPayload!.length} chars', name: 'Home.NFC');

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

      // ⚡ Share via instant NFC service with PRE-CACHED payload (NO async calls!)
      developer.log('🚀 Calling NFCService.shareProfileInstant() with cached payload...', name: 'Home.NFC');
      final startTime = DateTime.now();

      // Stay in ACTIVE state (breathing + ripples) until write completes
      // Writes are instant once tag is detected, so no loading state needed
      final result = await NFCService.shareProfileInstant(_cachedNfcPayload!);

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
    ShareModal.show(
      context,
      userName: 'John Doe',
      userEmail: 'john.doe@example.com',
      onNFCShare: _onNfcTap,
    );
  }

  void _showNfcSetupDialog() {
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
          Icons.nfc,
          color: AppColors.primaryAction,
          size: 32,
        ),
      ),
      title: 'Enable NFC',
      content: 'NFC is required to share your contact card. Please enable NFC in your device settings to continue.',
      actions: [
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          },
        ),
        DialogAction.primary(
          text: 'Settings',
          onPressed: () => _openNfcSettings(),
        ),
      ],
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
          Icons.nfc,
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
      // Close the current dialog first
      Navigator.of(context, rootNavigator: true).pop();

      // Try to open NFC settings using platform channels
      await _tryOpenNfcSettings();

      // After user returns from settings, refresh NFC status
      if (mounted) {
        _nfcAvailable = await NFCService.initialize();

        // Show result based on NFC state
        if (_nfcAvailable) {
          _showSuccessMessage('NFC is now enabled! You can share your card.');
        } else {
          _showNfcInstructionsDialog();
        }
      }
    } catch (e) {
      debugPrint('Error opening NFC settings: $e');
      if (mounted) {
        _showNfcInstructionsDialog();
      }
    }
  }

  Future<void> _tryOpenNfcSettings() async {
    // For now, we'll show instructions since platform-specific settings
    // opening requires additional native code setup
    // In a production app, you could use packages like 'app_settings'
    // or implement platform channels
    throw Exception('Settings opening not implemented - showing manual instructions');
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
          Icons.settings,
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
            content: Row(
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
            backgroundColor: AppColors.primaryAction,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.blueAccent),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      developer.log('⚡ Pre-caching NFC payload for instant sharing...', name: 'Home.NFC');
      final startTime = DateTime.now();

      // Get active profile (synchronous from service)
      final profile = await _getActiveProfileForSharing();

      if (profile == null) {
        developer.log('⚠️ No active profile found for caching', name: 'Home.NFC');
        if (mounted) {
          setState(() {
            _cachedActiveProfile = null;
            _cachedNfcPayload = null;
            _isPayloadReady = false;
          });
        }
        return;
      }

      // Get cached NFC payload (should be pre-generated)
      final payload = profile.getFreshNfcPayload();

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '✅ NFC payload cached in ${duration}ms\n'
        '   • Payload size: ${payload.length} chars\n'
        '   • Profile: ${profile.name}',
        name: 'Home.NFC'
      );

      if (mounted) {
        setState(() {
          _cachedActiveProfile = profile;
          _cachedNfcPayload = payload;
          _isPayloadReady = true;
        });
      }
    } catch (e) {
      developer.log('❌ Error pre-caching NFC payload: $e', name: 'Home.NFC', error: e);
      if (mounted) {
        setState(() {
          _cachedActiveProfile = null;
          _cachedNfcPayload = null;
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

  @override
  void dispose() {
    // Cancel state reset timer
    _stateResetTimer?.cancel();

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
    return Scaffold(
      key: const Key('home-screen'),
      body: Container(
        key: const Key('home-background'),
        width: double.infinity,
        height: double.infinity,
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
        child: RefreshIndicator(
          key: _refreshKey,
          onRefresh: _onRefresh,
          color: AppColors.primaryAction,
          backgroundColor: AppColors.surfaceDark,
          child: Column(
            key: const Key('home-layout'),
            children: [
              _buildGlassAppBar(),
              Expanded(
                key: const Key('home-content'),
                child: SingleChildScrollView(
                  key: const Key('home-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassAppBar() {
    return SafeArea(
      key: const Key('appbar-safe-area'),
      bottom: false,
      child: Container(
        key: const Key('appbar-container'),
        height: 64,
        margin: const EdgeInsets.all(16),
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                            Icons.nfc,
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
                    _buildAppBarIcon(Icons.settings_outlined, _onSettingsTap, 'settings'),
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
            color: AppColors.textSecondary,
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
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            _isPreviewMode ? Icons.nfc : Icons.preview,
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
    // Special case: NFC disabled
    if (!_nfcAvailable) {
      return Icon(
        Icons.nfc_outlined,
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
          Icons.nfc,
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
            Icons.nfc,
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
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );

      case NfcFabState.success:
        // Green checkmark with pop animation
        return ScaleTransition(
          key: const Key('home_nfc_fab_success'),
          scale: _successScale,
          child: Icon(
            Icons.check_circle,
            color: Colors.greenAccent,
            size: 56,
          ),
        );

      case NfcFabState.error:
        // Red X icon
        return Icon(
          Icons.error,
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
        // All use same orange gradient
        return {
          'primary': AppColors.primaryAction,
          'secondary': AppColors.secondaryAction,
        };

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
    // Determine text and color based on state
    String text;
    Color textColor;

    if (!_nfcAvailable) {
      text = 'NFC not available';
      textColor = AppColors.textSecondary;
    } else {
      switch (_nfcFabState) {
        case NfcFabState.inactive:
          text = 'Bring device close to share';
          textColor = Colors.white.withOpacity(0.6);  // Dull white
          break;

        case NfcFabState.active:
          text = 'Tap to Share';
          textColor = AppColors.primaryAction;  // Orange
          break;

        case NfcFabState.writing:
          // Writing state kept for compatibility but shows same as active
          // (Writes are instant, so this state is rarely seen)
          text = 'Tap to Share';
          textColor = AppColors.primaryAction;  // Orange
          break;

        case NfcFabState.success:
          text = 'Written successfully!';
          textColor = Colors.greenAccent;
          break;

        case NfcFabState.error:
          text = 'Write failed';
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
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              key: const Key('home_share_options_clip'),
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                key: const Key('home_share_options_backdrop'),
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  key: const Key('home_share_options_container'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    key: const Key('home_share_options_row'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        key: const Key('home_share_options_icon'),
                        size: 18,
                        color: AppColors.primaryAction,
                      ),
                      const SizedBox(key: Key('home_share_options_text_spacing'), width: 8),
                      Text(
                        'More sharing options',
                        key: const Key('home_share_options_text'),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primaryAction,
                          fontWeight: FontWeight.w500,
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

    final aesthetics = activeProfile.cardAesthetics;

    return Container(
      key: const Key('home_card_preview_container'),
      width: 300,
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background with profile colors
            Container(
              decoration: BoxDecoration(
                gradient: aesthetics.backgroundColor != null
                  ? LinearGradient(
                      colors: [
                        aesthetics.backgroundColor!,
                        aesthetics.backgroundColor!.withOpacity(0.8),
                      ],
                    )
                  : aesthetics.gradient,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            // Background image if present
            if (aesthetics.hasBackgroundImage)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    File(aesthetics.backgroundImagePath!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            // Glassmorphic overlay
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: aesthetics.blurLevel,
                sigmaY: aesthetics.blurLevel,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(aesthetics.hasBackgroundImage ? 0.1 : 0.2),
                      Colors.white.withOpacity(aesthetics.hasBackgroundImage ? 0.05 : 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: aesthetics.borderColor != Colors.transparent
                    ? Border.all(
                        color: aesthetics.borderColor.withOpacity(0.8),
                        width: 1.5,
                      )
                    : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
            // Content overlay for readability
            if (aesthetics.hasBackgroundImage)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            // Actual content
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with avatar and name
                  Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          gradient: activeProfile.profileImagePath != null
                            ? null
                            : aesthetics.gradient,
                          borderRadius: BorderRadius.circular(22.5),
                        ),
                        child: activeProfile.profileImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22.5),
                              child: Image.file(
                                File(activeProfile.profileImagePath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activeProfile.name.isNotEmpty ? activeProfile.name : 'Your Name',
                              key: const Key('home_card_preview_name'),
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            if (activeProfile.title != null && activeProfile.title!.isNotEmpty)
                              Text(
                                activeProfile.title!,
                                key: const Key('home_card_preview_title'),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Contact info
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.email,
                              key: const Key('home_card_preview_email_icon'),
                              size: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                activeProfile.email ?? 'email@example.com',
                                key: const Key('home_card_preview_email'),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              key: const Key('home_card_preview_phone_icon'),
                              size: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                activeProfile.phone ?? '+1 (555) 123-4567',
                                key: const Key('home_card_preview_phone'),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              key: const Key('home_card_preview_company_icon'),
                              size: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                activeProfile.company ?? 'Company Name',
                                key: const Key('home_card_preview_company'),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            Icons.people_outline,
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
          child: Text(
            'Recent Activity',
            key: const Key('home_history_title'),
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(key: Key('home_history_title_spacing'), height: 16),
        Container(
          key: const Key('home_history_list_container'),
          height: 200, // Increased height for vertical scrolling
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _recentHistory.isEmpty
              ? _buildHistoryEmpty()
              : _buildHistoryList(),
        ),
      ],
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
            Icons.history,
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

  Widget _buildHistoryList() {
    return ListView.builder(
      key: const Key('home_history_list_view'),
      scrollDirection: Axis.vertical,
      itemCount: _recentHistory.length,
      itemBuilder: (context, index) {
        final activity = _recentHistory[index];
        return _buildHistoryCard(activity, index);
      },
    );
  }

  Widget _buildHistoryCard(HistoryActivity activity, int index) {
    final colors = _getHistoryColors(activity.type);
    final icon = _getHistoryIcon(activity.type);

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
                  // TODO: Navigate to history details
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
                              _getHistoryTitle(activity.type),
                              key: Key('home_history_title_$index'),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              activity.contactName,
                              key: Key('home_history_name_$index'),
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatHistoryTime(activity.timestamp),
                              key: Key('home_history_time_$index'),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        activity.method,
                        key: Key('home_history_method_$index'),
                        style: AppTextStyles.caption.copyWith(
                          color: colors['text'],
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
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

  Map<String, Color> _getHistoryColors(HistoryType type) {
    switch (type) {
      case HistoryType.sent:
        return {
          'background': AppColors.primaryAction.withOpacity(0.1),
          'border': AppColors.primaryAction.withOpacity(0.3),
          'iconBg': AppColors.primaryAction.withOpacity(0.2),
          'icon': AppColors.primaryAction,
          'text': AppColors.primaryAction,
        };
      case HistoryType.received:
        return {
          'background': AppColors.success.withOpacity(0.1),
          'border': AppColors.success.withOpacity(0.3),
          'iconBg': AppColors.success.withOpacity(0.2),
          'icon': AppColors.success,
          'text': AppColors.success,
        };
      case HistoryType.qr:
        return {
          'background': AppColors.secondaryAction.withOpacity(0.1),
          'border': AppColors.secondaryAction.withOpacity(0.3),
          'iconBg': AppColors.secondaryAction.withOpacity(0.2),
          'icon': AppColors.secondaryAction,
          'text': AppColors.secondaryAction,
        };
    }
  }

  IconData _getHistoryIcon(HistoryType type) {
    switch (type) {
      case HistoryType.sent:
        return Icons.send;
      case HistoryType.received:
        return Icons.call_received;
      case HistoryType.qr:
        return Icons.qr_code_scanner;
    }
  }

  String _getHistoryTitle(HistoryType type) {
    switch (type) {
      case HistoryType.sent:
        return 'SENT TO';
      case HistoryType.received:
        return 'RECEIVED FROM';
      case HistoryType.qr:
        return 'QR SCANNED';
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

// History model classes
enum HistoryType {
  sent,
  received,
  qr,
}

class HistoryActivity {
  final HistoryType type;
  final String contactName;
  final DateTime timestamp;
  final String method;

  HistoryActivity({
    required this.type,
    required this.contactName,
    required this.timestamp,
    required this.method,
  });
}