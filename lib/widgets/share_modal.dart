import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme.dart';

enum ShareTab { qr, link }

class ShareModal extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? profileImageUrl;
  final VoidCallback? onNFCShare;

  const ShareModal({
    Key? key,
    required this.userName,
    required this.userEmail,
    this.profileImageUrl,
    this.onNFCShare,
  }) : super(key: key);

  @override
  State<ShareModal> createState() => _ShareModalState();

  static void show(
    BuildContext context, {
    required String userName,
    required String userEmail,
    String? profileImageUrl,
    VoidCallback? onNFCShare,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => ShareModal(
        userName: userName,
        userEmail: userEmail,
        profileImageUrl: profileImageUrl,
        onNFCShare: onNFCShare,
      ),
    );
  }
}

class _ShareModalState extends State<ShareModal>
    with TickerProviderStateMixin {
  ShareTab _currentTab = ShareTab.qr;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _tabController;
  late AnimationController _contentController;

  // Animations
  late Animation<double> _slideAnimation;
  late Animation<double> _contentFade;

  // Generated share data
  String _shareUrl = '';
  String _qrData = '';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _generateShareData();
    _startAnimations();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _tabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _contentFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    ));
  }

  void _generateShareData() {
    _shareUrl = 'https://tapcard.app/share/${widget.userName.toLowerCase().replaceAll(' ', '-')}';
    _qrData = 'BEGIN:VCARD\nVERSION:3.0\nFN:${widget.userName}\nEMAIL:${widget.userEmail}\nURL:$_shareUrl\nEND:VCARD';
  }

  void _startAnimations() {
    _slideController.forward();
    _tabController.forward();
    _contentController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _tabController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const Key('share_modal_animated_builder'),
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          key: const Key('share_modal_transform'),
          offset: Offset(0, _slideAnimation.value * MediaQuery.of(context).size.height * 0.5),
          child: Container(
            key: const Key('share_modal_container'),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
              minHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: _buildModalContent(),
          ),
        );
      },
    );
  }

  Widget _buildModalContent() {
    return Container(
      key: const Key('share_modal_outer_container'),
      margin: const EdgeInsets.all(12),
      child: ClipRRect(
        key: const Key('share_modal_clip'),
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          key: const Key('share_modal_backdrop'),
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            key: const Key('share_modal_content_container'),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  key: const Key('share_modal_main_column'),
                  children: [
                    _buildDragHandle(),
                    _buildHeader(),
                    _buildTabBar(),
                    Expanded(
                      key: const Key('share_modal_expanded_content'),
                      child: SingleChildScrollView(
                        key: const Key('share_modal_scroll_view'),
                        child: _buildTabContent(),
                      ),
                    ),
                    _buildSocialButtons(),
                    SizedBox(key: const Key('share_modal_bottom_spacing'), height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      key: const Key('share_modal_drag_handle'),
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.textTertiary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      key: const Key('share_modal_header_padding'),
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
      child: Row(
        key: const Key('share_modal_header_row'),
        children: [
          Hero(
            key: const Key('share_modal_profile_hero'),
            tag: 'profile_share',
            child: Container(
              key: const Key('share_modal_profile_container'),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.primaryAction.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: widget.profileImageUrl != null
                  ? ClipRRect(
                      key: const Key('share_modal_profile_image_clip'),
                      borderRadius: BorderRadius.circular(26),
                      child: Image.network(
                        key: const Key('share_modal_profile_image'),
                        widget.profileImageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      key: Key('share_modal_profile_placeholder_icon'),
                      Icons.person,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(key: Key('share_modal_header_spacing'), width: 16),
          Expanded(
            key: const Key('share_modal_header_text_section'),
            child: Column(
              key: const Key('share_modal_header_text_column'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: const Key('share_modal_title_text'),
                  'Share Your Card',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  key: const Key('share_modal_username_text'),
                  widget.userName,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Material(
            key: const Key('share_modal_close_button_material'),
            color: Colors.transparent,
            child: InkWell(
              key: const Key('share_modal_close_button_inkwell'),
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                key: const Key('share_modal_close_button_container'),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  key: Key('share_modal_close_icon'),
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      key: const Key('share_modal_tab_bar_container'),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassBorder.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        key: const Key('share_modal_tab_bar_row'),
        children: [
          _buildTab(ShareTab.qr, 'QR', Icons.qr_code),
          _buildTab(ShareTab.link, 'Link', Icons.link),
        ],
      ),
    );
  }

  Widget _buildTab(ShareTab tab, String label, IconData icon) {
    final isSelected = _currentTab == tab;

    return Expanded(
      key: Key('share_modal_tab_${tab.name}'),
      child: Material(
        key: Key('share_modal_tab_material_${tab.name}'),
        color: Colors.transparent,
        child: InkWell(
          key: Key('share_modal_tab_inkwell_${tab.name}'),
          onTap: () => _switchTab(tab),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            key: Key('share_modal_tab_container_${tab.name}'),
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryAction.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: AppColors.primaryAction.withOpacity(0.5),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? AppColors.primaryAction
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    color: isSelected
                        ? AppColors.primaryAction
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedBuilder(
      animation: _contentFade,
      builder: (context, child) {
        return FadeTransition(
          opacity: _contentFade,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _getTabContent(),
          ),
        );
      },
    );
  }

  Widget _getTabContent() {
    switch (_currentTab) {
      case ShareTab.qr:
        return _buildQRTab();
      case ShareTab.link:
        return _buildLinkTab();
    }
  }


  Widget _buildQRTab() {
    return Column(
      key: const Key('share_modal_qr_tab_column'),
      children: [
        const SizedBox(key: Key('share_modal_qr_top_spacing'), height: 20),
        Center(
          key: const Key('share_modal_qr_center'),
          child: Container(
            key: const Key('share_modal_qr_container'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowMedium.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              key: const Key('share_modal_qr_image'),
              data: _qrData,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              errorStateBuilder: (cxt, err) {
                return Container(
                  key: const Key('share_modal_qr_error_container'),
                  width: 200,
                  height: 200,
                  alignment: Alignment.center,
                  child: Text(
                    key: const Key('share_modal_qr_error_text'),
                    'Error generating QR code',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(key: Key('share_modal_qr_title_spacing'), height: 24),
        Text(
          key: const Key('share_modal_qr_title'),
          'Scan to Connect',
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(key: Key('share_modal_qr_subtitle_spacing'), height: 12),
        Text(
          key: const Key('share_modal_qr_subtitle'),
          'Open any QR scanner or camera app to instantly get my contact details',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(key: Key('share_modal_qr_buttons_spacing'), height: 24),
        Row(
          key: const Key('share_modal_qr_buttons_row'),
          children: [
            Expanded(
              key: const Key('share_modal_qr_save_button_section'),
              child: _buildActionButton(
                icon: Icons.download,
                label: 'Save QR',
                onTap: _saveQRCode,
              ),
            ),
            const SizedBox(key: Key('share_modal_qr_buttons_spacing_middle'), width: 16),
            Expanded(
              key: const Key('share_modal_qr_share_button_section'),
              child: _buildActionButton(
                icon: Icons.share,
                label: 'Share QR',
                onTap: _shareQRCode,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkTab() {
    return Column(
      key: const Key('share_modal_link_tab_column'),
      children: [
        const SizedBox(key: Key('share_modal_link_top_spacing'), height: 20),
        Container(
          key: const Key('share_modal_link_main_container'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassBorder.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.glassBorder.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            key: const Key('share_modal_link_content_column'),
            children: [
              Icon(
                key: const Key('share_modal_link_icon'),
                Icons.link,
                size: 48,
                color: AppColors.primaryAction,
              ),
              const SizedBox(key: Key('share_modal_link_icon_spacing'), height: 16),
              Text(
                key: const Key('share_modal_link_title'),
                'Share Link',
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(key: Key('share_modal_link_title_spacing'), height: 12),
              Container(
                key: const Key('share_modal_link_url_container'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  key: const Key('share_modal_link_url_row'),
                  children: [
                    Expanded(
                      key: const Key('share_modal_link_url_text_section'),
                      child: Text(
                        key: const Key('share_modal_link_url_text'),
                        _shareUrl,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(key: Key('share_modal_link_url_spacing'), width: 12),
                    Material(
                      key: const Key('share_modal_link_copy_button_material'),
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('share_modal_link_copy_button_inkwell'),
                        onTap: _copyLink,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          key: const Key('share_modal_link_copy_button_container'),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            key: const Key('share_modal_link_copy_icon'),
                            Icons.copy,
                            size: 18,
                            color: AppColors.primaryAction,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(key: Key('share_modal_link_info_spacing'), height: 24),
        Text(
          key: const Key('share_modal_link_info_text'),
          'Anyone with this link can view and save your contact information',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(key: Key('share_modal_link_buttons_spacing'), height: 24),
        Row(
          key: const Key('share_modal_link_buttons_row'),
          children: [
            Expanded(
              key: const Key('share_modal_link_copy_button_section'),
              child: _buildActionButton(
                icon: Icons.copy,
                label: 'Copy Link',
                onTap: _copyLink,
              ),
            ),
            const SizedBox(key: Key('share_modal_link_buttons_spacing_middle'), width: 16),
            Expanded(
              key: const Key('share_modal_link_share_button_section'),
              child: _buildActionButton(
                icon: Icons.share,
                label: 'Share Link',
                onTap: _shareLink,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      key: Key('share_modal_action_button_${label.toLowerCase().replaceAll(' ', '_')}_material'),
      color: Colors.transparent,
      child: InkWell(
        key: Key('share_modal_action_button_${label.toLowerCase().replaceAll(' ', '_')}_inkwell'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          key: Key('share_modal_action_button_${label.toLowerCase().replaceAll(' ', '_')}_container'),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryAction.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryAction.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            key: Key('share_modal_action_button_${label.toLowerCase().replaceAll(' ', '_')}_row'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                key: Key('share_modal_action_button_${label.toLowerCase().replaceAll(' ', '_')}_icon'),
                icon,
                size: 20,
                color: AppColors.primaryAction,
              ),
              SizedBox(key: Key('share_modal_action_button_${label.toLowerCase().replaceAll(' ', '_')}_spacing'), width: 8),
              Text(
                key: Key('share_modal_action_button_${label.toLowerCase().replaceAll(' ', '_')}_text'),
                label,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.primaryAction,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Container(
      key: const Key('share_modal_social_buttons_container'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        key: const Key('share_modal_social_buttons_column'),
        children: [
          const Divider(
            key: Key('share_modal_social_divider'),
            color: AppColors.glassBorder,
            height: 1,
          ),
          const SizedBox(key: Key('share_modal_social_divider_spacing'), height: 16),
          Text(
            key: const Key('share_modal_social_title'),
            'Share via',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(key: Key('share_modal_social_title_spacing'), height: 16),
          Row(
            key: const Key('share_modal_social_buttons_row'),
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton(
                icon: Icons.message_rounded,
                label: 'SMS',
                color: AppColors.success,
                onTap: _shareViaSMS,
              ),
              _buildSocialButton(
                icon: Icons.chat_bubble_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: _shareViaWhatsApp,
              ),
              _buildSocialButton(
                icon: Icons.email_rounded,
                label: 'Email',
                color: AppColors.info,
                onTap: _shareViaEmail,
              ),
              _buildSocialButton(
                icon: Icons.share_rounded,
                label: 'More',
                color: AppColors.textSecondary,
                onTap: _shareViaOther,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      key: Key('share_modal_social_${label.toLowerCase()}_material'),
      color: Colors.transparent,
      child: InkWell(
        key: Key('share_modal_social_${label.toLowerCase()}_inkwell'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          key: Key('share_modal_social_${label.toLowerCase()}_container'),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            key: Key('share_modal_social_${label.toLowerCase()}_icon'),
            icon,
            color: color,
            size: 24,
          ),
        ),
      ),
    );
  }

  void _switchTab(ShareTab tab) {
    if (_currentTab == tab) return;

    setState(() => _currentTab = tab);
    HapticFeedback.lightImpact();

    // Animate content transition
    _contentController.reset();
    _contentController.forward();
  }


  Future<void> _copyLink() async {
    try {
      await Clipboard.setData(ClipboardData(text: _shareUrl));
      HapticFeedback.lightImpact();
      _showSuccessSnackBar('Link copied to clipboard');
    } catch (e) {
      _showErrorSnackBar('Failed to copy link');
    }
  }

  Future<void> _shareLink() async {
    try {
      HapticFeedback.lightImpact();
      await Share.share(
        'Check out ${widget.userName}\'s contact card: $_shareUrl',
        subject: '${widget.userName}\'s Contact Card',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to share link');
    }
  }

  Future<void> _saveQRCode() async {
    try {
      HapticFeedback.lightImpact();
      // TODO: Implement QR code saving to gallery
      _showSuccessSnackBar('QR code saved to gallery');
    } catch (e) {
      _showErrorSnackBar('Failed to save QR code');
    }
  }

  Future<void> _shareQRCode() async {
    try {
      HapticFeedback.lightImpact();
      // TODO: Implement QR code sharing
      _showSuccessSnackBar('QR code shared');
    } catch (e) {
      _showErrorSnackBar('Failed to share QR code');
    }
  }

  Future<void> _shareViaSMS() async {
    try {
      HapticFeedback.lightImpact();
      final uri = Uri(
        scheme: 'sms',
        queryParameters: {
          'body': 'Here\'s my contact card: $_shareUrl',
        },
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch SMS';
      }
    } catch (e) {
      _showErrorSnackBar('SMS not available');
    }
  }

  Future<void> _shareViaWhatsApp() async {
    try {
      HapticFeedback.lightImpact();
      final text = Uri.encodeComponent('Check out my contact card: $_shareUrl');
      final uri = Uri.parse('whatsapp://send?text=$text');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'WhatsApp not installed';
      }
    } catch (e) {
      _showErrorSnackBar('WhatsApp not available');
    }
  }

  Future<void> _shareViaEmail() async {
    try {
      HapticFeedback.lightImpact();
      final uri = Uri(
        scheme: 'mailto',
        queryParameters: {
          'subject': '${widget.userName}\'s Contact Card',
          'body': 'Hi!\n\nI\'d like to share my contact details with you: $_shareUrl\n\nBest regards,\n${widget.userName}',
        },
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Email not available';
      }
    } catch (e) {
      _showErrorSnackBar('Email not available');
    }
  }

  Future<void> _shareViaOther() async {
    try {
      HapticFeedback.lightImpact();
      await Share.share(
        'Check out ${widget.userName}\'s contact card: $_shareUrl',
        subject: '${widget.userName}\'s Contact Card',
      );
    } catch (e) {
      _showErrorSnackBar('Sharing not available');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 12),
            Text(message, style: AppTextStyles.body),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: AppColors.error),
            const SizedBox(width: 12),
            Text(message, style: AppTextStyles.body),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

}