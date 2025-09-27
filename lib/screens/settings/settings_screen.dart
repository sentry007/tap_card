import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/profile_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  // Services
  late ProfileService _profileService;

  // User profile data
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

  // Appearance settings
  String _themeMode = 'dark'; // 'light', 'dark', 'system'
  double _glassIntensity = 0.15;

  // NFC settings (moved from old version)
  bool _nfcEnabled = true;
  bool _autoShare = false;

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
    if (mounted) {
      setState(() {
        _multipleProfiles = _profileService.multipleProfilesEnabled;
        // Update user profile data from active profile
        final activeProfile = _profileService.activeProfile;
        if (activeProfile != null) {
          _userName = activeProfile.name.isNotEmpty ? activeProfile.name : 'John Doe';
          _userEmail = activeProfile.email ?? 'john.doe@example.com';
        }
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
            Icon(
              Icons.warning,
              color: AppColors.warning,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
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
        content: Row(
          children: [
            Icon(Icons.group, color: AppColors.success),
            const SizedBox(width: 12),
            Text(
              'Multiple profiles enabled',
              style: AppTextStyles.body,
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMultipleProfilesDisabledSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.person, color: AppColors.info),
            const SizedBox(width: 12),
            Text(
              'Multiple profiles disabled',
              style: AppTextStyles.body,
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
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
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildUserProfileHeader(),
                    const SizedBox(height: 24),
                    _buildAccountSettings(),
                    const SizedBox(height: 24),
                    _buildPrivacyControls(),
                    const SizedBox(height: 24),
                    _buildNotificationPreferences(),
                    const SizedBox(height: 24),
                    _buildAppearanceSettings(),
                    const SizedBox(height: 24),
                    _buildNFCSettings(),
                    const SizedBox(height: 24),
                    _buildAdvancedOptions(),
                    const SizedBox(height: 100), // Space for bottom nav
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
      expandedHeight: 60,
      floating: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        key: const Key('settings_appbar_flexible_space'),
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          key: const Key('settings_appbar_title_row'),
          children: [
            Text(
              key: const Key('settings_appbar_title_text'),
              'Settings',
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(key: Key('settings_appbar_spacer')),
            GlassCard(
              key: const Key('settings_appbar_help_card'),
              padding: const EdgeInsets.all(8),
              margin: EdgeInsets.zero,
              borderRadius: 12,
              onTap: () {
                // TODO: Show help/support
              },
              child: const Icon(
                key: Key('settings_appbar_help_icon'),
                Icons.help_outline_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ],
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
            child: GlassCardVariant(
              type: GlassCardType.elevated,
              onTap: () => _showEditProfileDialog(),
              child: Column(
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: 'profile_image',
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: AppColors.primaryAction.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: _profileImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(33),
                                  child: Image.network(
                                    _profileImageUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(33),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.textPrimary,
                                    size: 35,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: AppTextStyles.h3.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail,
                              style: AppTextStyles.bodySecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to edit profile',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryAction,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAction.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: AppColors.primaryAction,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(
                    color: AppColors.glassBorder,
                    height: 1,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProfileStat('Shared', '127'),
                      _buildProfileStat('Received', '89'),
                      _buildProfileStat('Contacts', '45'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            color: AppColors.primaryAction,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildAccountSettings() {
    return _buildSettingsSection(
      'Account Settings',
      Icons.account_circle,
      [
        _buildSwitchTile(
          icon: Icons.group_rounded,
          title: 'Multiple Profiles',
          subtitle: 'Manage multiple contact profiles',
          value: _multipleProfiles,
          onChanged: _toggleMultipleProfiles,
        ),
        _buildActionTile(
          icon: Icons.download_rounded,
          title: 'Export Data',
          subtitle: 'Download your data as JSON/CSV',
          onTap: () => _showExportDialog(),
        ),
        _buildActionTile(
          icon: Icons.backup_rounded,
          title: 'Backup & Sync',
          subtitle: 'Sync data across devices',
          onTap: () {
            // TODO: Navigate to backup settings
          },
        ),
      ],
    );
  }

  Widget _buildPrivacyControls() {
    return _buildSettingsSection(
      'Privacy & Security',
      Icons.security,
      [
        _buildSwitchTile(
          icon: Icons.analytics_outlined,
          title: 'Analytics',
          subtitle: 'Help improve the app with usage data',
          value: _analyticsEnabled,
          onChanged: (value) => setState(() => _analyticsEnabled = value),
        ),
        _buildSwitchTile(
          icon: Icons.bug_report_outlined,
          title: 'Crash Reporting',
          subtitle: 'Send crash reports to help fix issues',
          value: _crashReporting,
          onChanged: (value) => setState(() => _crashReporting = value),
        ),
        _buildSliderTile(
          icon: Icons.timer_rounded,
          title: 'Share Expiry',
          subtitle: 'Auto-revoke shares after $_shareExpiry days',
          value: _shareExpiry.toDouble(),
          min: 1,
          max: 365,
          divisions: 364,
          onChanged: (value) => setState(() => _shareExpiry = value.round()),
        ),
        _buildActionTile(
          icon: Icons.block_rounded,
          title: 'Revoke All Shares',
          subtitle: 'Remove access to all shared contacts',
          onTap: () => _showRevokeAllDialog(),
          isDestructive: true,
        ),
        _buildActionTile(
          icon: Icons.security_rounded,
          title: 'Privacy Policy',
          subtitle: 'View our privacy policy',
          onTap: () {
            // TODO: Show privacy policy
          },
        ),
      ],
    );
  }

  Widget _buildNotificationPreferences() {
    return _buildSettingsSection(
      'Notifications',
      Icons.notifications,
      [
        _buildSwitchTile(
          icon: Icons.notifications_active_rounded,
          title: 'Push Notifications',
          subtitle: 'Receive notifications from the app',
          value: _pushNotifications,
          onChanged: (value) => setState(() => _pushNotifications = value),
        ),
        _buildSwitchTile(
          icon: Icons.share_rounded,
          title: 'Share Notifications',
          subtitle: 'Notify when you share contact info',
          value: _shareNotifications,
          onChanged: (value) => setState(() => _shareNotifications = value),
        ),
        _buildSwitchTile(
          icon: Icons.call_received_rounded,
          title: 'Receive Notifications',
          subtitle: 'Notify when you receive contact info',
          value: _receiveNotifications,
          onChanged: (value) => setState(() => _receiveNotifications = value),
        ),
        _buildSwitchTile(
          icon: Icons.volume_up_rounded,
          title: 'Sound',
          subtitle: 'Play sound for sharing events',
          value: _soundEnabled,
          onChanged: (value) => setState(() => _soundEnabled = value),
        ),
        _buildSwitchTile(
          icon: Icons.vibration_rounded,
          title: 'Vibration',
          subtitle: 'Vibrate on successful sharing',
          value: _vibrationEnabled,
          onChanged: (value) => setState(() => _vibrationEnabled = value),
        ),
      ],
    );
  }

  Widget _buildAppearanceSettings() {
    return _buildSettingsSection(
      'Appearance',
      Icons.palette,
      [
        _buildSelectionTile(
          icon: Icons.brightness_6_rounded,
          title: 'Theme',
          subtitle: 'Choose app theme',
          options: const ['Light', 'Dark', 'System'],
          selectedIndex: ['light', 'dark', 'system'].indexOf(_themeMode),
          onChanged: (index) {
            setState(() {
              _themeMode = ['light', 'dark', 'system'][index];
            });
            _showThemeChangeSnackBar();
          },
        ),
        _buildSliderTile(
          icon: Icons.blur_on_rounded,
          title: 'Glass Intensity',
          subtitle: 'Adjust glassmorphism effect strength',
          value: _glassIntensity,
          min: 0.05,
          max: 0.3,
          divisions: 25,
          onChanged: (value) => setState(() => _glassIntensity = value),
        ),
      ],
    );
  }

  Widget _buildNFCSettings() {
    return _buildSettingsSection(
      'NFC & Sharing',
      Icons.nfc,
      [
        _buildSwitchTile(
          icon: Icons.nfc_rounded,
          title: 'NFC Enabled',
          subtitle: 'Allow NFC sharing and receiving',
          value: _nfcEnabled,
          onChanged: (value) => setState(() => _nfcEnabled = value),
        ),
        _buildSwitchTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Auto Share',
          subtitle: 'Automatically share when NFC is detected',
          value: _autoShare,
          onChanged: (value) => setState(() => _autoShare = value),
        ),
        _buildActionTile(
          icon: Icons.qr_code_rounded,
          title: 'QR Code Settings',
          subtitle: 'Configure QR code generation',
          onTap: () {
            // TODO: Navigate to QR settings
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return _buildSettingsSection(
      'Advanced',
      Icons.settings,
      [
        _buildActionTile(
          icon: Icons.info_outline_rounded,
          title: 'About',
          subtitle: 'App version and information',
          onTap: () => _showAboutDialog(),
        ),
        _buildActionTile(
          icon: Icons.description_rounded,
          title: 'Terms of Service',
          subtitle: 'View terms and conditions',
          onTap: () {
            // TODO: Show terms of service
          },
        ),
        _buildActionTile(
          icon: Icons.support_agent_rounded,
          title: 'Help & Support',
          subtitle: 'Get help or contact support',
          onTap: () {
            // TODO: Navigate to support
          },
        ),
        _buildActionTile(
          icon: Icons.rate_review_outlined,
          title: 'Rate App',
          subtitle: 'Rate us on the App Store',
          onTap: () {
            // TODO: Open app store rating
          },
        ),
        _buildActionTile(
          icon: Icons.feedback_rounded,
          title: 'Send Feedback',
          subtitle: 'Share your thoughts with us',
          onTap: () {
            // TODO: Open feedback form
          },
        ),
        _buildActionTile(
          icon: Icons.delete_outline_rounded,
          title: 'Clear All Data',
          subtitle: 'Remove all app data permanently',
          onTap: () => _showClearDataDialog(),
          isDestructive: true,
        ),
        _buildActionTile(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          onTap: () => _showSignOutDialog(),
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: AppColors.primaryAction,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.h3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
          endIndent: 16,
        ));
      }
    }
    return result;
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.highlight,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Switch(
              key: ValueKey(value),
              value: value,
              onChanged: (newValue) {
                HapticFeedback.selectionClick();
                onChanged(newValue);
              },
              activeTrackColor: AppColors.primaryAction.withOpacity(0.5),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryAction;
                }
                return AppColors.textTertiary;
              }),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final iconColor = isDestructive ? AppColors.error : AppColors.highlight;
    final titleColor = isDestructive ? AppColors.error : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: iconColor.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.highlight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.highlight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryAction,
              inactiveTrackColor: AppColors.glassBorder,
              thumbColor: AppColors.primaryAction,
              overlayColor: AppColors.primaryAction.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (newValue) {
                HapticFeedback.selectionClick();
                onChanged(newValue);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.highlight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.highlight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = index == selectedIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                      right: index < options.length - 1 ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryAction.withOpacity(0.2)
                          : AppColors.glassBorder.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryAction
                            : AppColors.glassBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: isSelected
                            ? AppColors.primaryAction
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Profile',
          style: AppTextStyles.h3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              onTap: () {
                // TODO: Implement photo picker
              },
              child: Row(
                children: [
                  const Icon(Icons.photo_camera),
                  const SizedBox(width: 12),
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
          TextButton(
            onPressed: () {
              setState(() {
                _userName = nameController.text;
                _userEmail = emailController.text;
              });
              Navigator.pop(context);
              _showUpdateSuccessSnackBar();
            },
            child: Text(
              'Save',
              style: AppTextStyles.body.copyWith(
                color: AppColors.primaryAction,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Export Data',
          style: AppTextStyles.h3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose the format for your data export:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Export as JSON
                      _showExportSuccessSnackBar('JSON');
                    },
                    child: Column(
                      children: [
                        const Icon(Icons.data_object, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'JSON',
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassCard(
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Export as CSV
                      _showExportSuccessSnackBar('CSV');
                    },
                    child: Column(
                      children: [
                        const Icon(Icons.table_chart, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'CSV',
                          style: AppTextStyles.body,
                        ),
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
      ),
    );
  }

  void _showRevokeAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Revoke All Shares',
          style: AppTextStyles.h3.copyWith(color: AppColors.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'This will immediately revoke access to all your shared contact information. Recipients will no longer be able to view your details.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Revoke all shares
              _showRevokeSuccessSnackBar();
            },
            child: Text(
              'Revoke All',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear All Data',
          style: AppTextStyles.h3.copyWith(color: AppColors.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_forever,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'This will permanently delete all your data including:',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Column(
              key: const Key('settings_delete_account_list'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key: const Key('settings_delete_account_contact_info'), '• Contact information', style: AppTextStyles.body),
                Text(key: const Key('settings_delete_account_sharing_history'), '• Sharing history', style: AppTextStyles.body),
                Text(key: const Key('settings_delete_account_app_preferences'), '• App preferences', style: AppTextStyles.body),
                Text(key: const Key('settings_delete_account_account_settings'), '• Account settings', style: AppTextStyles.body),
              ],
            ),
            const SizedBox(height: 16),
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Clear all data
              final appState = context.read<AppState>();
              appState.resetAppState();
            },
            child: Text(
              'Delete Everything',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
                Icons.nfc,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'About Tap Card',
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
                Text(
                  '1.0.0',
                  style: AppTextStyles.body,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
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
            Column(
              key: const Key('settings_about_features_list'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key: const Key('settings_about_nfc_feature'), '• NFC-enabled contact sharing', style: AppTextStyles.bodySecondary),
                Text(key: const Key('settings_about_qr_feature'), '• QR code generation', style: AppTextStyles.bodySecondary),
                Text(key: const Key('settings_about_privacy_feature'), '• Privacy controls', style: AppTextStyles.bodySecondary),
                Text(key: const Key('settings_about_design_feature'), '• Beautiful glassmorphism design', style: AppTextStyles.bodySecondary),
                Text(key: const Key('settings_about_appearance_feature'), '• Customizable appearance', style: AppTextStyles.bodySecondary),
              ],
            ),
            const SizedBox(height: 16),
            Row(
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: AppTextStyles.h3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.logout,
              color: AppColors.primaryAction,
              size: 48,
            ),
            const SizedBox(height: 16),
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final appState = context.read<AppState>();
              appState.signOut();
              _showSignOutSuccessSnackBar();
            },
            child: Text(
              'Sign Out',
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

  void _showUpdateSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 12),
            Text(
              'Profile updated successfully',
              style: AppTextStyles.body,
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showExportSuccessSnackBar(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.download_done, color: AppColors.success),
            const SizedBox(width: 12),
            Text(
              'Data exported as $format',
              style: AppTextStyles.body,
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
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
        content: Row(
          children: [
            Icon(Icons.block, color: AppColors.warning),
            const SizedBox(width: 12),
            Text(
              'All shares have been revoked',
              style: AppTextStyles.body,
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSignOutSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.logout, color: AppColors.info),
            const SizedBox(width: 12),
            Text(
              'Signed out successfully',
              style: AppTextStyles.body,
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showThemeChangeSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.palette, color: AppColors.highlight),
            const SizedBox(width: 12),
            Text(
              'Theme will be applied in next update',
              style: AppTextStyles.body,
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}