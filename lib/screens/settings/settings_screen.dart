import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/settings/settings_tiles.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/profile_models.dart';
import '../../core/constants/app_constants.dart';
import '../../services/nfc_service.dart';
import '../../services/nfc_settings_service.dart';
import '../../services/history_service.dart';
import '../../services/settings_service.dart';
import '../../services/tutorial_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/logger.dart';
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

  // UI settings
  final double _glassIntensity = 0.15; // Keep for GlassCard opacity

  // NFC settings (moved from old version)
  bool _nfcEnabled = true;
  bool _autoShare = false;
  NfcMode _defaultNfcMode = NfcMode.tagWrite;
  bool _locationTracking = false;
  ProfileType _defaultShareProfile = ProfileType.personal;

  // History settings
  int _historyRetentionDays = 365; // Default to 1 year

  // Developer settings
  bool _devModeEnabled = false;

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

        // Update default share profile from active profile
        if (activeProfile != null) {
          _defaultShareProfile = activeProfile.type;
        }

        // Update app settings from loaded data
        _analyticsEnabled = settings['analyticsEnabled'] ?? true;
        _crashReporting = settings['crashReporting'] ?? true;
        _nfcEnabled = settings['nfcEnabled'] ?? true;
        _autoShare = settings['autoShare'] ?? false;
        _devModeEnabled = settings['devModeEnabled'] ?? false;
        _historyRetentionDays = settings['historyRetentionDays'] ?? 365;
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
    _showGlassDialog(
      title: 'Disable Multiple Profiles',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: AppColors.warning,
            size: 48,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'This will keep only your active profile and remove all other profiles permanently.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
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
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        DialogAction.primary(
          text: 'Disable',
          isDestructive: true,
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
        ),
      ],
    );
  }

  void _showMultipleProfilesEnabledSnackBar() {
    SnackbarHelper.showSuccess(
      context,
      message: 'Multiple profiles enabled',
      icon: CupertinoIcons.group,
    );
  }

  void _showMultipleProfilesDisabledSnackBar() {
    SnackbarHelper.showInfo(
      context,
      message: 'Multiple profiles disabled',
      icon: CupertinoIcons.person,
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
      body: Stack(
        children: [
          // Background gradient (full screen, extends behind nav bar)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.surfaceGradient,
              ),
            ),
          ),
          // Content (with SafeArea)
          SafeArea(
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
        ],
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
                  AppColors.surfaceDark.withValues(alpha: 0.8),
                  AppColors.surfaceDark.withValues(alpha: 0.5),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.glassBorder.withValues(alpha: 0.2),
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
                          color: AppColors.primaryAction.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: _showHelpDialog,
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
                      AppColors.primaryAction.withValues(alpha: 0.05),
                      AppColors.secondaryAction.withValues(alpha: 0.05),
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
                              color: AppColors.primaryAction.withValues(alpha: 0.3),
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
    final authService = AuthService();
    final isAuthenticated = authService.isSignedIn;
    final isGuest = authService.isAnonymous;
    final authProviderName = authService.authProviderName;
    final userEmail = authService.email;
    final userPhone = authService.phoneNumber;

    return _buildSettingsSection(
      'Account Settings',
      CupertinoIcons.person_circle,
      [
        // Authentication status info
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (isGuest ? AppColors.warning : AppColors.success).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  isGuest ? CupertinoIcons.person : CupertinoIcons.checkmark_shield,
                  color: isGuest ? AppColors.warning : AppColors.success,
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
                      isAuthenticated ? 'Signed In' : 'Not Signed In',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isAuthenticated
                          ? (isGuest
                              ? 'Guest Account'
                              : '$authProviderName${userEmail != null ? " • $userEmail" : userPhone != null ? " • $userPhone" : ""}')
                          : 'Sign in to sync your data',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Upgrade account for guest users
        if (isGuest)
          SettingsActionTile(
            icon: CupertinoIcons.arrow_up_circle,
            title: 'Upgrade Account',
            subtitle: 'Link to Google or Phone to keep your data',
            onTap: () {
              // Sign out to go back to auth screen where they can link
              _showUpgradeAccountDialog();
            },
          ),

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
          onTap: null,
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
              SnackbarHelper.showInfo(
                context,
                message: 'Tutorial reset! Navigate to Home to start.',
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
        _buildDefaultShareProfileTile(),
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
                builder: (context) => QrSettingsScreen(
                  userName: _userName,
                  profileImageUrl: _profileImageUrl,
                ),
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
    final authService = AuthService();
    final isAuthenticated = authService.isSignedIn;

    return _buildSettingsSection(
      'Advanced',
      CupertinoIcons.settings,
      [
        SettingsSwitchTile(
          icon: CupertinoIcons.hammer,
          title: 'Developer Mode',
          subtitle: 'Show mock data for testing',
          value: _devModeEnabled,
          onChanged: (value) async {
            if (value) {
              _showDevModeEnableDialog();
            } else {
              setState(() => _devModeEnabled = false);
              await SettingsService.setDevModeEnabled(false);

              // Clear mock data from history
              await HistoryService.clearMockData();

              _showDevModeDisabledSnackBar();
            }
          },
        ),
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
          onTap: _showHelpDialog,
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
        SettingsSliderTile(
          icon: CupertinoIcons.calendar,
          title: 'History Retention',
          subtitle: _historyRetentionDays >= 365
              ? 'Keep history forever'
              : 'Auto-delete after $_historyRetentionDays days',
          value: _historyRetentionDays.toDouble(),
          min: 7,
          max: 365,
          divisions: 358,
          onChanged: (value) async {
            final days = value.round();
            setState(() => _historyRetentionDays = days);
            await SettingsService.setHistoryRetentionDays(days);
          },
        ),
        SettingsActionTile(
          icon: CupertinoIcons.trash_circle,
          title: 'Clear History',
          subtitle: 'Remove all sharing history',
          onTap: () => _showClearHistoryDialog(),
          isDestructive: true,
        ),
        SettingsActionTile(
          icon: CupertinoIcons.delete,
          title: 'Clear All Data',
          subtitle: 'Remove all app data permanently',
          onTap: () => _showClearDataDialog(),
          isDestructive: true,
        ),
        if (isAuthenticated)
          SettingsActionTile(
            icon: CupertinoIcons.arrow_right_square,
            title: 'Sign Out',
            subtitle: 'Sign out of your account',
            onTap: () => _showSignOutDialog(),
          ),
        if (isAuthenticated)
          SettingsActionTile(
            icon: CupertinoIcons.trash,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and data',
            onTap: () => _showDeleteAccountDialog(),
            isDestructive: true,
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
                  color: AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: AppColors.highlight,
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
              color: AppColors.highlight.withValues(alpha: 0.1),
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
              color: AppColors.surfaceDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.glassBorder.withValues(alpha: 0.2),
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

  Widget _buildDefaultShareProfileTile() {
    return GestureDetector(
      onTap: _showProfilePickerSheet,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.highlight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                CupertinoIcons.person_crop_square,
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
                    'Default Profile',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Profile type to share by default',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getProfileDisplayName(_defaultShareProfile),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    color: AppColors.textSecondary,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProfileDisplayName(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return 'Personal';
      case ProfileType.professional:
        return 'Professional';
      case ProfileType.custom:
        return 'Custom';
    }
  }

  void _showProfilePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Select Default Profile',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Options
              _buildProfileOption(
                type: ProfileType.personal,
                icon: CupertinoIcons.person,
                title: 'Personal',
                subtitle: 'Share personal contact info',
              ),
              _buildProfileOption(
                type: ProfileType.professional,
                icon: CupertinoIcons.briefcase,
                title: 'Professional',
                subtitle: 'Share work contact info',
              ),
              _buildProfileOption(
                type: ProfileType.custom,
                icon: CupertinoIcons.star,
                title: 'Custom',
                subtitle: 'Share custom contact info',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required ProfileType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _defaultShareProfile == type;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
            ? AppColors.primaryAction.withValues(alpha: 0.2)
            : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.primaryAction : AppColors.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? AppColors.primaryAction : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption,
      ),
      trailing: isSelected
        ? const Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.primaryAction, size: 22)
        : null,
      onTap: () async {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        setState(() => _defaultShareProfile = type);
        await _profileService.setActiveProfileByType(type);
      },
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
  // Uses DialogAction callbacks to avoid context shadowing issues
  Future<T?> _showGlassDialog<T>({
    required String title,
    required Widget content,
    List<DialogAction>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => BackdropFilter(
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
                  AppColors.surfaceDark.withValues(alpha: 0.95),
                  AppColors.surfaceDark.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppColors.glassBorder.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
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
                        color: AppColors.glassBorder.withValues(alpha: 0.2),
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
                // Actions - build buttons internally using DialogAction callbacks
                if (actions != null && actions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: AppColors.glassBorder.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions.map((action) => Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: TextButton(
                          onPressed: action.onPressed,
                          style: TextButton.styleFrom(
                            backgroundColor: action.isPrimary
                                ? (action.isDestructive
                                    ? AppColors.warning.withValues(alpha: 0.2)
                                    : AppColors.primaryAction.withValues(alpha: 0.2))
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                          child: Text(
                            action.text,
                            style: AppTextStyles.body.copyWith(
                              color: action.isPrimary
                                  ? (action.isDestructive ? AppColors.warning : AppColors.primaryAction)
                                  : AppColors.textSecondary,
                              fontWeight: action.isPrimary ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    _showGlassDialog(
      title: 'Clear History',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.trash_circle, color: AppColors.warning, size: 48),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'This will permanently delete all your sharing history including sent, received, and tag write records.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your profile and settings will not be affected.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        DialogAction.primary(
          text: 'Clear History',
          isDestructive: true,
          onPressed: () async {
            Navigator.pop(context);
            await HistoryService.clearAllHistory();
            if (mounted) {
              SnackbarHelper.showSuccess(
                context,
                message: 'History cleared successfully',
                icon: CupertinoIcons.checkmark_circle,
              );
            }
          },
        ),
      ],
    );
  }

  void _showHelpDialog() {
    _showGlassDialog(
      title: 'Help & Quick Tips',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpItem(
            icon: CupertinoIcons.radiowaves_right,
            title: 'NFC Sharing',
            description: 'Tap your phone against another NFC-enabled device to instantly share your profile.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildHelpItem(
            icon: CupertinoIcons.qrcode,
            title: 'QR Code',
            description: 'Share your profile by having others scan your QR code from the home screen.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildHelpItem(
            icon: CupertinoIcons.person_2,
            title: 'Multiple Profiles',
            description: 'Create separate profiles for personal and professional use. Enable in Account Settings.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildHelpItem(
            icon: CupertinoIcons.clock,
            title: 'History',
            description: 'Track all your profile shares in the History tab. See who you connected with and when.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildHelpItem(
            icon: CupertinoIcons.lightbulb,
            title: 'Need more help?',
            description: 'Use the "Restart Tutorial" option in Help & Tutorial section to review the guided tour.',
          ),
        ],
      ),
      actions: [
        DialogAction.primary(
          text: 'Got it',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Icon(icon, size: 18, color: AppColors.highlight),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showUpgradeAccountDialog() {
    _showGlassDialog(
      title: 'Upgrade Account',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.arrow_up_circle, color: AppColors.primaryAction, size: 48),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Upgrade from a guest account to a full account by signing in with Google or Phone.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your data will be preserved after upgrading.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        DialogAction.primary(
          text: 'Upgrade Now',
          onPressed: () {
            Logger.info('Upgrade account button tapped', name: 'SETTINGS');
            final appState = context.read<AppState>();
            Navigator.of(context, rootNavigator: true).pop();
            SchedulerBinding.instance.addPostFrameCallback((_) async {
              try {
                Logger.info('Signing out to show auth options...', name: 'SETTINGS');
                await appState.signOut();
                Logger.info('User will be redirected to splash/auth screen', name: 'SETTINGS');
              } catch (e, stackTrace) {
                Logger.error('Upgrade account error: $e', name: 'SETTINGS', error: e, stackTrace: stackTrace);
              }
            });
          },
        ),
      ],
    );
  }

  void _showDeleteAccountDialog() {
    _showGlassDialog(
      title: 'Delete Account',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.trash, color: AppColors.error, size: 48),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'This will permanently delete your account and all associated data including:',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Your profile information', style: AppTextStyles.body),
              Text('• All sharing history', style: AppTextStyles.body),
              Text('• App preferences', style: AppTextStyles.body),
              Text('• Account credentials', style: AppTextStyles.body),
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
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        DialogAction.primary(
          text: 'Delete Account',
          isDestructive: true,
          onPressed: () async {
            Logger.info('Delete account button tapped', name: 'SETTINGS');
            Navigator.pop(context);
            try {
              Logger.info('Calling authService.deleteAccount()...', name: 'SETTINGS');
              final authService = AuthService();
              await authService.deleteAccount();
              Logger.info('Account deleted successfully', name: 'SETTINGS');
              if (mounted) {
                SnackbarHelper.showSuccess(
                  context,
                  message: 'Account deleted successfully',
                );
              }
            } catch (e, stackTrace) {
              Logger.error('Delete account error: $e', name: 'SETTINGS', error: e, stackTrace: stackTrace);
              if (mounted) {
                SnackbarHelper.showError(
                  context,
                  message: 'Failed to delete account: $e',
                );
              }
            }
          },
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
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        DialogAction(
          text: 'Delete Everything',
          isDestructive: true,
          onPressed: () {
            Logger.info('Clear all data button tapped', name: 'SETTINGS');

            // ✅ CRITICAL: Capture AppState BEFORE popping dialog
            final appState = context.read<AppState>();

            // ✅ CRITICAL: Use rootNavigator to pop ONLY the dialog, not GoRouter's stack
            Navigator.of(context, rootNavigator: true).pop();

            // ✅ CRITICAL: Defer reset until AFTER dialog navigation completes
            SchedulerBinding.instance.addPostFrameCallback((_) {
              Logger.info('Resetting app state...', name: 'SETTINGS');
              appState.resetAppState();
              Logger.info('App state reset - all data cleared', name: 'SETTINGS');
            });
          },
        ),
      ],
    );
  }

  void _showAboutDialog() {
    _showGlassDialog(
      title: 'About Atlas Linq',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 1,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.antenna_radiowaves_left_right,
                  color: AppColors.highlight,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version: 1.0.0',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Build: 2024.03.15',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'A modern NFC sharing app with beautiful glassmorphism UI design. Share your contact information effortlessly with just a tap.',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Features:',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('• NFC-enabled contact sharing', style: AppTextStyles.bodySecondary),
          const Text('• QR code generation', style: AppTextStyles.bodySecondary),
          const Text('• Privacy controls', style: AppTextStyles.bodySecondary),
          const Text('• Multiple profile types', style: AppTextStyles.bodySecondary),
          const Text('• Sharing history tracking', style: AppTextStyles.bodySecondary),
        ],
      ),
      actions: [
        DialogAction.secondary(
          text: 'Licenses',
          onPressed: () {
            // TODO: Open license page
          },
        ),
        DialogAction.primary(
          text: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showDevModeEnableDialog() {
    _showGlassDialog(
      title: 'Enable Developer Mode',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.hammer, color: AppColors.highlight, size: 48),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Developer mode will populate the app with mock data for testing purposes.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This is useful for testing but should be turned off for beta users.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        DialogAction.primary(
          text: 'Enable',
          onPressed: () async {
            // Pop the dialog first
            Navigator.of(context, rootNavigator: true).pop();

            // Then update state and settings
            if (mounted) {
              setState(() => _devModeEnabled = true);
              await SettingsService.setDevModeEnabled(true);

              // Regenerate mock data for history and analytics
              await HistoryService.regenerateMockData();

              _showDevModeEnabledSnackBar();
            }
          },
        ),
      ],
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
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        DialogAction.primary(
          text: 'Sign Out',
          onPressed: () {
            Logger.info('Sign-out button tapped', name: 'SETTINGS');

            // ✅ CRITICAL: Capture AppState BEFORE popping dialog
            final appState = context.read<AppState>();

            // ✅ CRITICAL: Use rootNavigator to pop ONLY the dialog, not GoRouter's stack
            // This prevents "no pages left to show" error from GoRouter
            Navigator.of(context, rootNavigator: true).pop();

            // ✅ CRITICAL: Defer sign-out until AFTER dialog navigation completes
            // This prevents Navigator lock conflict when router tries to redirect
            SchedulerBinding.instance.addPostFrameCallback((_) async {
              try {
                Logger.info('Calling appState.signOut()...', name: 'SETTINGS');
                await appState.signOut();
                Logger.info('Sign-out completed - router will redirect to splash', name: 'SETTINGS');
              } catch (e, stackTrace) {
                Logger.error('Sign-out error: $e', name: 'SETTINGS', error: e, stackTrace: stackTrace);
              }
            });
          },
        ),
      ],
    );
  }

  void _showDevModeEnabledSnackBar() {
    SnackbarHelper.showSuccess(
      context,
      message: 'Developer mode enabled',
      icon: CupertinoIcons.hammer_fill,
    );
  }

  void _showDevModeDisabledSnackBar() {
    SnackbarHelper.showInfo(
      context,
      message: 'Developer mode disabled',
      icon: CupertinoIcons.hammer,
    );
  }

  void _showErrorSnackBar(String message) {
    SnackbarHelper.showError(
      context,
      message: message,
    );
  }
}