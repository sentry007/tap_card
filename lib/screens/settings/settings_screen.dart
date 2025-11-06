import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/settings/settings_tiles.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/profile_service.dart';
import '../../core/constants/app_constants.dart';
import '../../services/nfc_service.dart';
import '../../services/nfc_settings_service.dart';
import '../../services/history_service.dart';
import '../../services/settings_service.dart';
import '../../services/tutorial_service.dart';
import '../../widgets/tutorial/tutorial.dart';
import 'profile_detail_modal.dart';
import 'qr_settings_screen.dart';
import 'package:app_settings/app_settings.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  // Services
  late ProfileService _profileService;

  // User profile data (loaded from active profile)
  String _userName = 'John Doe';
  String _userEmail = 'john.doe@example.com';
  String? _profileImageUrl;

  // Account settings
  bool _multipleProfiles = false;

  // Privacy controls
  bool _analyticsEnabled = true;
  bool _crashReporting = true;
  int _shareExpiry = 30; // days

  // Notification preferences
  bool _pushNotifications = true;
  bool _shareNotifications = true;
  bool _receiveNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // UI settings
  final double _glassIntensity = 0.15; // Keep for GlassCard opacity

  // NFC settings (moved from old version)
  bool _nfcEnabled = true;
  bool _autoShare = false;
  NfcMode _defaultNfcMode = NfcMode.tagWrite;
  bool _locationTracking = false;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    _initializeServices();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _initializeServices() async {
    await _profileService.initialize();
    await NfcSettingsService.initialize();
    await HistoryService.initialize();
    await SettingsService.initialize();

    // Load NFC settings
    final defaultMode = await NfcSettingsService.getDefaultMode();
    final locationEnabled = await NfcSettingsService.getLocationTrackingEnabled();

    // Load app settings
    final settings = await SettingsService.loadAllSettings();

    // Get active profile
    final activeProfile = _profileService.activeProfile;

    if (mounted) {
      setState(() {
        _multipleProfiles = _profileService.multipleProfilesEnabled;

        // Update user profile data from active profile
        if (activeProfile != null) {
          _userName = activeProfile.name.isNotEmpty ? activeProfile.name : 'John Doe';
          _userEmail = activeProfile.email ?? 'john.doe@example.com';
          _profileImageUrl = activeProfile.profileImagePath;
        }

        // Update NFC settings
        _defaultNfcMode = defaultMode;
        _locationTracking = locationEnabled;

        // Update app settings from loaded data
        _analyticsEnabled = settings['analyticsEnabled'] ?? true;
        _crashReporting = settings['crashReporting'] ?? true;
        _shareExpiry = settings['shareExpiry'] ?? 30;
        _pushNotifications = settings['pushNotifications'] ?? true;
        _shareNotifications = settings['shareNotifications'] ?? true;
        _receiveNotifications = settings['receiveNotifications'] ?? true;
        _soundEnabled = settings['soundEnabled'] ?? true;
        _vibrationEnabled = settings['vibrationEnabled'] ?? true;
        _nfcEnabled = settings['nfcEnabled'] ?? true;
        _autoShare = settings['autoShare'] ?? false;
      });
    }
  }

  void _toggleMultipleProfiles(bool value) async {
    if (value) {
      await _profileService.enableMultipleProfiles();
      _showMultipleProfilesEnabledSnackBar();
    } else {
      _showDisableMultipleProfilesDialog();
    }

    if (mounted) {
      setState(() {
        _multipleProfiles = _profileService.multipleProfilesEnabled;
      });
    }
  }

  void _showDisableMultipleProfilesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Disable Multiple Profiles',
          style: AppTextStyles.h3.copyWith(color: AppColors.warning),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: AppColors.warning,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'This will keep only your active profile and remove all other profiles permanently.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _profileService.disableMultipleProfiles();
              _showMultipleProfilesDisabledSnackBar();
              if (mounted) {
                setState(() {
                  _multipleProfiles = _profileService.multipleProfilesEnabled;
                });
              }
            },
            child: Text(
              'Disable',
              style: AppTextStyles.body.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMultipleProfilesEnabledSnackBar() {
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
              child: const Row(
                children: [
                  Icon(CupertinoIcons.group, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Multiple profiles enabled',
                      style: AppTextStyles.body,
                    ),
                  ),
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
  }

  void _showMultipleProfilesDisabledSnackBar() {
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
              child: const Row(
                children: [
                  Icon(CupertinoIcons.person, color: Colors.blueAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Multiple profiles disabled',
                      style: AppTextStyles.body,
                    ),
                  ),
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
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.surfaceGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildUserProfileHeader(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildAccountSettings(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildPrivacyControls(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildNFCSettings(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildNotificationPreferences(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTutorialSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildAdvancedOptions(),
                    const SizedBox(height: AppSpacing.bottomNavHeight + AppSpacing.md),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      key: const Key('settings_sliver_appbar'),
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surfaceDark.withOpacity(0.8),
                  AppColors.surfaceDark.withOpacity(0.5),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.glassBorder.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: FlexibleSpaceBar(
              key: const Key('settings_appbar_flexible_space'),
              titlePadding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
              ),
              title: Row(
                key: const Key('settings_appbar_title_row'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    key: const Key('settings_appbar_title_text'),
                    'Settings',
                    style: AppTextStyles.h2.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryAction.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () {
                          // TODO: Show help/support
                        },
                        child: const Icon(
                          key: Key('settings_appbar_help_icon'),
                          CupertinoIcons.question_circle,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfileHeader() {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideController.value)),
          child: Opacity(
            opacity: _fadeController.value,
            child: GlassCard(
              padding: EdgeInsets.zero,
              onTap: () {
                HapticFeedback.lightImpact();
                // Show full profile modal
                final activeProfile = _profileService.activeProfile;
                if (activeProfile != null) {
                  ProfileDetailModal.show(context, activeProfile);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryAction.withOpacity(0.05),
                      AppColors.secondaryAction.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: 'profile_image_${_profileService.activeProfile?.id ?? 'default'}',
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: AppColors.primaryAction.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: Image.network(
                                    _profileImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.person,
                                        color: AppColors.textPrimary,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.person,
                                    color: AppColors.textPrimary,
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: AppTextStyles.h3.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _userEmail,
                              style: AppTextStyles.bodySecondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                    ],
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

  Widget _buildAccountSettings() {
    return _buildSettingsSection(
      'Account Settings',
      CupertinoIcons.person_circle,
      [
        SettingsSwitchTile(
          icon: CupertinoIcons.person_3,
          title: 'Multiple Profiles',
          subtitle: 'Manage multiple contact profiles',
          value: _multipleProfiles,
          onChanged: _toggleMultipleProfiles,
        ),
        const SettingsActionTile(
          icon: CupertinoIcons.arrow_up_circle,
          title: 'Backup & Sync',
          subtitle: 'Sync data across devices',
          onTap: null, // TODO: Requires Firebase Auth
          isDisabled: true,
          badge: 'Coming Soon',
        ),
      ],
    );
  }

  Widget _buildPrivacyControls() {
    return _buildSettingsSection(
      'Privacy & Security',
      CupertinoIcons.lock_shield,
      [
        SettingsSwitchTile(
          icon: CupertinoIcons.chart_bar,
          title: 'Analytics',
          subtitle: 'Help improve the app with usage data',
          value: _analyticsEnabled,
          onChanged: (value) async {
            setState(() => _analyticsEnabled = value);
            await SettingsService.setAnalyticsEnabled(value);
          },
        ),
        SettingsSwitchTile(
          icon: CupertinoIcons.ant,
          title: 'Crash Reporting',
          subtitle: 'Send crash reports to help fix issues',
          value: _crashReporting,
          onChanged: (value) async {
            setState(() => _crashReporting = value);
            await SettingsService.setCrashReportingEnabled(value);
          },
        ),
        SettingsSliderTile(
          icon: CupertinoIcons.timer,
          title: 'Share Expiry',
          subtitle: 'Auto-revoke shares after $_shareExpiry days',
          value: _shareExpiry.toDouble(),
          min: 1,
          max: 365,
          divisions: 364,
          onChanged: (value) async {
            final days = value.round();
            setState(() => _shareExpiry = days);
            await SettingsService.setShareExpiryDays(days);
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.hand_raised,
          title: 'Revoke All Shares',
          subtitle: 'Remove access to all shared contacts',
          onTap: () => _showRevokeAllDialog(),
          isDestructive: true,
        ),
        SettingsActionTile(
          icon: CupertinoIcons.lock_fill,
          title: 'Privacy Policy',
          subtitle: 'View our privacy policy',
          onTap: () {
            // TODO: Show privacy policy
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.lock_shield,
          title: 'App Permissions',
          subtitle: 'Manage app permissions in system settings',
          onTap: () async {
            try {
              await AppSettings.openAppSettings();
            } catch (e) {
              _showErrorSnackBar('Could not open settings');
            }
          },
        ),
      ],
    );
  }

  Widget _buildNotificationPreferences() {
    return _buildSettingsSection(
      'Notifications',
      CupertinoIcons.bell,
      [
        SettingsSwitchTile(
          icon: CupertinoIcons.bell_fill,
          title: 'Push Notifications',
          subtitle: 'Receive notifications from the app',
          value: _pushNotifications,
          onChanged: (value) async {
            setState(() => _pushNotifications = value);
            await SettingsService.setPushNotificationsEnabled(value);
          },
        ),
        SettingsSwitchTile(
          icon: CupertinoIcons.share,
          title: 'Share Notifications',
          subtitle: 'Notify when you share contact info',
          value: _shareNotifications,
          onChanged: (value) async {
            setState(() => _shareNotifications = value);
            await SettingsService.setShareNotificationsEnabled(value);
          },
        ),
        SettingsSwitchTile(
          icon: CupertinoIcons.arrow_down_left,
          title: 'Receive Notifications',
          subtitle: 'Notify when you receive contact info',
          value: _receiveNotifications,
          onChanged: (value) async {
            setState(() => _receiveNotifications = value);
            await SettingsService.setReceiveNotificationsEnabled(value);
          },
        ),
        SettingsSwitchTile(
          icon: CupertinoIcons.speaker_2,
          title: 'Sound',
          subtitle: 'Play sound for sharing events',
          value: _soundEnabled,
          onChanged: (value) async {
            setState(() => _soundEnabled = value);
            await SettingsService.setSoundEnabled(value);
          },
        ),
        SettingsSwitchTile(
          icon: CupertinoIcons.device_phone_portrait,
          title: 'Vibration',
          subtitle: 'Vibrate on successful sharing',
          value: _vibrationEnabled,
          onChanged: (value) async {
            setState(() => _vibrationEnabled = value);
            await SettingsService.setVibrationEnabled(value);
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.settings,
          title: 'System Notification Settings',
          subtitle: 'Manage notifications in system settings',
          onTap: () async {
            try {
              await AppSettings.openAppSettings(type: AppSettingsType.notification);
            } catch (e) {
              _showErrorSnackBar('Could not open notification settings');
            }
          },
        ),
      ],
    );
  }


  Widget _buildTutorialSection() {
    return _buildSettingsSection(
      'Help & Tutorial',
      CupertinoIcons.book,
      [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FutureBuilder<int>(
            future: TutorialService.getTutorialProgress(),
            builder: (context, snapshot) {
              final progress = snapshot.data ?? 0;
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.highlight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      CupertinoIcons.chart_bar_square,
                      color: AppColors.highlight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tutorial Progress',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '$progress% complete',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (progress == 100)
                    const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: AppColors.success,
                      size: 24,
                    ),
                ],
              );
            },
          ),
        ),
        SettingsActionTile(
          icon: CupertinoIcons.arrow_clockwise,
          title: 'Restart Tutorial',
          subtitle: 'Replay the interactive guide',
          onTap: () async {
            await TutorialService.resetTutorial();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tutorial reset! Navigate to Home to start.'),
                  duration: Duration(seconds: 2),
                ),
              );
              // Navigate to home screen with tutorial
              context.go('/home');
            }
          },
        ),
      ],
    );
  }

  Widget _buildNFCSettings() {
    return _buildSettingsSection(
      'NFC & Sharing',
      CupertinoIcons.antenna_radiowaves_left_right,
      [
        SettingsSwitchTile(
          icon: CupertinoIcons.antenna_radiowaves_left_right,
          title: 'NFC Enabled',
          subtitle: 'Allow NFC sharing and receiving (app-level)',
          value: _nfcEnabled,
          onChanged: (value) async {
            setState(() => _nfcEnabled = value);
            await SettingsService.setNfcEnabled(value);
          },
        ),
        SettingsSwitchTile(
          icon: CupertinoIcons.sparkles,
          title: 'Auto Share',
          subtitle: 'Automatically share when NFC is detected',
          value: _autoShare,
          onChanged: (value) async {
            setState(() => _autoShare = value);
            await SettingsService.setAutoShareEnabled(value);
          },
        ),
        _buildDefaultNfcModeTile(),
        SettingsSwitchTile(
          icon: CupertinoIcons.location_fill,
          title: 'Track Location',
          subtitle: 'Save location when sharing cards',
          value: _locationTracking,
          onChanged: (value) async {
            setState(() => _locationTracking = value);
            await NfcSettingsService.setLocationTrackingEnabled(value);
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.qrcode,
          title: 'QR Code Settings',
          subtitle: 'Configure QR code generation',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const QrSettingsScreen(),
              ),
            );
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.settings,
          title: 'System NFC Settings',
          subtitle: 'Open device NFC settings',
          onTap: () async {
            try {
              await AppSettings.openAppSettings(type: AppSettingsType.nfc);
            } catch (e) {
              _showErrorSnackBar('NFC settings not available on this device');
            }
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return _buildSettingsSection(
      'Advanced',
      CupertinoIcons.settings,
      [
        SettingsActionTile(
          icon: CupertinoIcons.info_circle,
          title: 'About',
          subtitle: 'App version and information',
          onTap: () => _showAboutDialog(),
        ),
        SettingsActionTile(
          icon: CupertinoIcons.doc_text,
          title: 'Terms of Service',
          subtitle: 'View terms and conditions',
          onTap: () {
            // TODO: Show terms of service
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.chat_bubble_2,
          title: 'Help & Support',
          subtitle: 'Get help or contact support',
          onTap: () {
            // TODO: Navigate to support
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.star,
          title: 'Rate App',
          subtitle: 'Rate us on the App Store',
          onTap: () {
            // TODO: Open app store rating
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.chat_bubble_text,
          title: 'Send Feedback',
          subtitle: 'Share your thoughts with us',
          onTap: () {
            // TODO: Open feedback form
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.delete,
          title: 'Clear All Data',
          subtitle: 'Remove all app data permanently',
          onTap: () => _showClearDataDialog(),
          isDestructive: true,
        ),
        const SettingsActionTile(
          icon: CupertinoIcons.arrow_right_square,
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          onTap: null, // TODO: Requires Firebase Auth
          isDisabled: true,
          badge: 'Requires Auth',
        ),
      ],
    );
  }

  Widget _buildSettingsSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            right: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryAction.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                title,
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          opacity: _glassIntensity,
          child: Column(
            children: _addDividers(children),
          ),
        ),
      ],
    );
  }

  List<Widget> _addDividers(List<Widget> children) {
    final List<Widget> result = [];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(const Divider(
          color: AppColors.glassBorder,
          height: 1,
          indent: 60,
          endIndent: AppSpacing.md,
        ));
      }
    }
    return result;
  }

  Widget _buildDefaultNfcModeTile() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              CupertinoIcons.arrow_up_arrow_down_square,
              color: AppColors.highlight,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Default NFC Mode',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Choose your preferred FAB mode',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.glassBorder.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Column(
              children: [
                _buildToggleOption(
                  icon: CupertinoIcons.tag_fill,
                  label: 'Tag',
                  isSelected: _defaultNfcMode == NfcMode.tagWrite,
                  color: AppColors.primaryAction,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    setState(() => _defaultNfcMode = NfcMode.tagWrite);
                    await NfcSettingsService.setDefaultMode(NfcMode.tagWrite);
                  },
                ),
                const SizedBox(height: 3),
                _buildToggleOption(
                  icon: CupertinoIcons.radiowaves_right,
                  label: 'P2P',
                  isSelected: _defaultNfcMode == NfcMode.p2pShare,
                  color: AppColors.p2pPrimary,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    setState(() => _defaultNfcMode = NfcMode.p2pShare);
                    await NfcSettingsService.setDefaultMode(NfcMode.p2pShare);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.textTertiary,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Glassmorphic dialog helper for consistent styling
  Future<T?> _showGlassDialog<T>({
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceDark.withOpacity(0.95),
                  AppColors.surfaceDark.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppColors.glassBorder.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.glassBorder.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    title,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: content,
                  ),
                ),
                // Actions
                if (actions != null && actions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: AppColors.glassBorder.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    _showGlassDialog(
      title: 'Edit Profile',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            style: AppTextStyles.body,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(CupertinoIcons.person),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: emailController,
            style: AppTextStyles.body,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(CupertinoIcons.mail),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            onTap: () {
              // TODO: Implement photo picker
            },
            child: const Row(
              children: [
                Icon(CupertinoIcons.camera),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Change Profile Photo',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: () {
            setState(() {
              _userName = nameController.text;
              _userEmail = emailController.text;
            });
            Navigator.pop(context);
            _showUpdateSuccessSnackBar();
          },
          style: TextButton.styleFrom(
            backgroundColor: AppColors.primaryAction.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
          ),
          child: Text(
            'Save',
            style: AppTextStyles.body.copyWith(
              color: AppColors.primaryAction,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showExportDialog() {
    _showGlassDialog(
      title: 'Export Data',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose the format for your data export:',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  onTap: () {
                    Navigator.pop(context);
                    _showExportSuccessSnackBar('JSON');
                  },
                  child: const Column(
                    children: [
                      Icon(CupertinoIcons.doc_on_doc, size: 32),
                      SizedBox(height: AppSpacing.sm),
                      Text('JSON', style: AppTextStyles.body),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GlassCard(
                  onTap: () {
                    Navigator.pop(context);
                    _showExportSuccessSnackBar('CSV');
                  },
                  child: const Column(
                    children: [
                      Icon(CupertinoIcons.table, size: 32),
                      SizedBox(height: AppSpacing.sm),
                      Text('CSV', style: AppTextStyles.body),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _showRevokeAllDialog() {
    _showGlassDialog(
      title: 'Revoke All Shares',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle, color: AppColors.error, size: 48),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'This will immediately revoke access to all your shared contact information. Recipients will no longer be able to view your details.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This action cannot be undone.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showRevokeSuccessSnackBar();
          },
          style: TextButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
          ),
          child: Text(
            'Revoke All',
            style: AppTextStyles.body.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showClearDataDialog() {
    _showGlassDialog(
      title: 'Clear All Data',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.trash, color: AppColors.error, size: 48),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'This will permanently delete all your data including:',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Column(
            key: Key('settings_delete_account_list'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(key: Key('settings_delete_account_contact_info'), '• Contact information', style: AppTextStyles.body),
              Text(key: Key('settings_delete_account_sharing_history'), '• Sharing history', style: AppTextStyles.body),
              Text(key: Key('settings_delete_account_app_preferences'), '• App preferences', style: AppTextStyles.body),
              Text(key: Key('settings_delete_account_account_settings'), '• Account settings', style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This action cannot be undone.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            final appState = context.read<AppState>();
            appState.resetAppState();
          },
          style: TextButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
          ),
          child: Text(
            'Delete Everything',
            style: AppTextStyles.body.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.antenna_radiowaves_left_right,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'About Atlas Linq',
              style: AppTextStyles.h3,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Version: ',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  '1.0.0',
                  style: AppTextStyles.body,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'A modern NFC sharing app with beautiful glassmorphism UI design. Share your contact information effortlessly with just a tap.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.glassBorder),
            const SizedBox(height: 16),
            Text(
              'Features:',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Column(
              key: Key('settings_about_features_list'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key: Key('settings_about_nfc_feature'), '• NFC-enabled contact sharing', style: AppTextStyles.bodySecondary),
                Text(key: Key('settings_about_qr_feature'), '• QR code generation', style: AppTextStyles.bodySecondary),
                Text(key: Key('settings_about_privacy_feature'), '• Privacy controls', style: AppTextStyles.bodySecondary),
                Text(key: Key('settings_about_design_feature'), '• Beautiful glassmorphism design', style: AppTextStyles.bodySecondary),
                Text(key: Key('settings_about_appearance_feature'), '• Customizable appearance', style: AppTextStyles.bodySecondary),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Text(
                  'Build: ',
                  style: AppTextStyles.caption,
                ),
                Text(
                  '2024.03.15',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Open license page
            },
            child: Text(
              'Licenses',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: AppTextStyles.body.copyWith(
                color: AppColors.primaryAction,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    _showGlassDialog(
      title: 'Sign Out',
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.square_arrow_right, color: AppColors.primaryAction, size: 48),
          SizedBox(height: AppSpacing.md),
          Text(
            'Are you sure you want to sign out? Your data will remain safe and you can sign back in anytime.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            final appState = context.read<AppState>();
            appState.signOut();
            _showSignOutSuccessSnackBar();
          },
          style: TextButton.styleFrom(
            backgroundColor: AppColors.primaryAction.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
          ),
          child: Text(
            'Sign Out',
            style: AppTextStyles.body.copyWith(
              color: AppColors.primaryAction,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showUpdateSuccessSnackBar() {
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
              child: const Row(
                children: [
                  Icon(CupertinoIcons.checkmark_circle, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Profile updated successfully',
                      style: AppTextStyles.body,
                    ),
                  ),
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
  }

  void _showExportSuccessSnackBar(String format) {
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
                  const Icon(CupertinoIcons.checkmark_circle, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Data exported as $format',
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View',
          textColor: AppColors.primaryAction,
          onPressed: () {
            // TODO: Open exported file
          },
        ),
      ),
    );
  }

  void _showRevokeSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.hand_raised_fill, color: AppColors.warning),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All shares have been revoked',
                      style: AppTextStyles.body,
                    ),
                  ),
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

  void _showSignOutSuccessSnackBar() {
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
              child: const Row(
                children: [
                  Icon(CupertinoIcons.square_arrow_right, color: Colors.blueAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Signed out successfully',
                      style: AppTextStyles.body,
                    ),
                  ),
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
  }

  void _showThemeChangeSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.highlight.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.highlight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.paintbrush, color: AppColors.highlight),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Theme will be applied in next update',
                      style: AppTextStyles.body,
                    ),
                  ),
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
  }

  void _showErrorSnackBar(String message) {
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
                  const Icon(CupertinoIcons.exclamationmark_circle, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: AppTextStyles.body,
                    ),
                  ),
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
}