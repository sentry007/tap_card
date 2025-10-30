import 'dart:ui';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme.dart';
import '../core/models/profile_models.dart';
import '../models/history_models.dart';
import '../services/qr_settings_service.dart';

class ShareModal extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? profileImageUrl;
  final VoidCallback? onNFCShare;
  final ProfileData profile;  // Full profile data for generating metadata

  const ShareModal({
    super.key,
    required this.userName,
    required this.userEmail,
    this.profileImageUrl,
    this.onNFCShare,
    required this.profile,
  });

  @override
  State<ShareModal> createState() => _ShareModalState();

  static void show(
    BuildContext context, {
    required String userName,
    required String userEmail,
    String? profileImageUrl,
    VoidCallback? onNFCShare,
    required ProfileData profile,
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
        profile: profile,
      ),
    );
  }
}

class _ShareModalState extends State<ShareModal>
    with SingleTickerProviderStateMixin {
  // Animation controller (slide-in only)
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  // Generated share data
  String _shareUrl = '';
  String _qrData = '';

  // QR settings
  QrSize _qrSize = QrSize.medium;
  int _errorCorrectionLevel = QrErrorCorrectLevel.M;
  int _colorMode = 0;
  Color _borderColor = AppColors.p2pSecondary;
  bool _showInitials = false;
  String _initials = '';

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _loadQrSettings();
    _generateShareData();
    _startAnimation();
  }

  Future<void> _loadQrSettings() async {
    await QrSettingsService.initialize();
    final size = await QrSettingsService.getQrSize();
    final errorLevel = await QrSettingsService.getErrorCorrectionLevel();
    final colorMode = await QrSettingsService.getColorMode();
    final borderColorValue = await QrSettingsService.getBorderColor();
    final showInitials = await QrSettingsService.getShowInitials();
    final initials = await QrSettingsService.getInitials();

    if (mounted) {
      setState(() {
        _qrSize = size;
        _errorCorrectionLevel = errorLevel;
        _colorMode = colorMode;
        _borderColor = borderColorValue != null ? Color(borderColorValue) : AppColors.p2pSecondary;
        _showInitials = showInitials;
        _initials = initials ?? '';
      });
    }
  }

  void _initAnimation() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _generateShareData() {
    // Generate URL from profile
    _shareUrl = widget.profile.dualPayload['url']!;

    // Generate QR code vCard WITH metadata (method: QR, fresh timestamp)
    final qrContext = ShareContext(
      method: ShareMethod.qr,
      timestamp: DateTime.now(),
    );
    final qrPayload = widget.profile.getDualPayloadWithContext(qrContext);
    _qrData = qrPayload['vcard']!;

    developer.log(
      '✅ Share data generated with metadata\n'
      '   • URL: $_shareUrl\n'
      '   • QR vCard: ${_qrData.length} bytes (with X-TC metadata)',
      name: 'ShareModal'
    );
  }

  void _startAnimation() {
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
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
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            key: const Key('share_modal_content_container'),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              key: const Key('share_modal_main_column'),
              children: [
                _buildDragHandle(),
                _buildHeader(),
                Expanded(
                  key: const Key('share_modal_expanded_content'),
                  child: SingleChildScrollView(
                    key: const Key('share_modal_scroll_view'),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: _buildScrollableContent(),
                  ),
                ),
                SizedBox(key: const Key('share_modal_bottom_spacing'), height: MediaQuery.of(context).padding.bottom + 8),
              ],
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
                      CupertinoIcons.person,
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
                  CupertinoIcons.xmark,
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

  // New scrollable content (no tabs - all sections in one scroll)
  Widget _buildScrollableContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PRIMARY: Nearby Share (compact)
        _buildCompactNearbyShare(),

        const SizedBox(height: 16),
        _buildSectionDivider(),
        const SizedBox(height: 16),

        // SECONDARY: QR Code (compact)
        _buildCompactQRCode(),

        const SizedBox(height: 16),
        _buildSectionDivider(),
        const SizedBox(height: 16),

        // TERTIARY: Link Section (compact)
        _buildCompactLinkSection(),

        const SizedBox(height: 16),
        _buildSectionDivider(),
        const SizedBox(height: 16),

        // QUATERNARY: Social Share
        _buildSocialButtons(),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSectionDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.glassBorder.withOpacity(0.3),
    );
  }

  // ==================== COMPACT SECTION BUILDERS ====================

  Widget _buildCompactNearbyShare() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _shareContactViaNearbyShare,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryAction.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_up_right_circle_fill,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Contact',
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose AirDrop, Nearby Share & more',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                CupertinoIcons.chevron_right,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactQRCode() {
    return Column(
      children: [
        Text(
          'QR Code',
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _colorMode == 1
              ? QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: _qrSize.pixels.toDouble(),
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: _errorCorrectionLevel,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: _borderColor,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                )
              : QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: _qrSize.pixels.toDouble(),
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: _errorCorrectionLevel,
                ),
        ),
        const SizedBox(height: 12),
        Text(
          'Scan to save contact',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share Link',
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _shareUrl,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _copyLink,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      CupertinoIcons.doc_on_doc,
                      size: 18,
                      color: AppColors.primaryAction,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Anyone with this link can view your contact information',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ==================== SOCIAL SHARE BUTTONS ====================

  Widget _buildSocialButtons() {
    return Container(
      key: const Key('share_modal_social_buttons_container'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        key: const Key('share_modal_social_buttons_column'),
        children: [
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
                icon: CupertinoIcons.chat_bubble,
                label: 'SMS',
                color: AppColors.success,
                onTap: _shareViaSMS,
              ),
              _buildSocialButton(
                icon: CupertinoIcons.chat_bubble_2_fill,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: _shareViaWhatsApp,
              ),
              _buildSocialButton(
                icon: CupertinoIcons.mail,
                label: 'Email',
                color: AppColors.info,
                onTap: _shareViaEmail,
              ),
              _buildSocialButton(
                icon: CupertinoIcons.share,
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

  // ==================== VCARD FILE CREATION ====================

  /// Create vCard file with metadata for AirDrop/Nearby Share
  /// Generates fresh vCard with metadata (method: link, timestamp)
  Future<XFile?> _createVCardFile() async {
    try {
      // Generate fresh vCard with metadata for Nearby Share
      final shareContext = ShareContext(
        method: ShareMethod.web,  // Web-based sharing (URL/nearby)
        timestamp: DateTime.now(),
      );
      final payload = widget.profile.getDualPayloadWithContext(shareContext);
      final vCard = payload['vcard']!;

      final fileName = '${widget.userName.replaceAll(' ', '_')}.vcf';
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(vCard);

      developer.log(
        '✅ vCard file created with metadata: ${vCard.length} bytes → $fileName\n'
        '   • Method: ${shareContext.method.label}\n'
        '   • Timestamp: ${shareContext.timestamp}',
        name: 'ShareModal'
      );

      return XFile(filePath, mimeType: 'text/x-vcard', name: fileName);
    } catch (e) {
      developer.log('❌ Error creating vCard file: $e', name: 'ShareModal');
      return null;
    }
  }

  /// Share contact via AirDrop/Nearby Share (vCard file only)
  Future<void> _shareContactViaNearbyShare() async {
    try {
      HapticFeedback.mediumImpact();

      final vcf = await _createVCardFile();

      if (vcf != null) {
        // Share vCard file WITHOUT text - clean AirDrop/Nearby Share UX
        await Share.shareXFiles([vcf]);
        developer.log('✅ Shared vCard via Nearby Share/AirDrop', name: 'ShareModal');
        _showSuccessSnackBar('Contact shared successfully');
      } else {
        _showErrorSnackBar('Failed to create contact file');
      }
    } catch (e) {
      developer.log('❌ Nearby Share failed: $e', name: 'ShareModal');
      _showErrorSnackBar('Failed to share contact');
    }
  }

  // ==================== ACTION HANDLERS ====================

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

      // Share LINK ONLY (no vCard file)
      // This is for passing around URLs via text/social
      await Share.share(
        'Check out ${widget.userName}\'s contact card: $_shareUrl',
        subject: '${widget.userName}\'s Contact Card',
      );
      developer.log('✅ Shared link only', name: 'ShareModal');
    } catch (e) {
      developer.log('❌ Share failed: $e', name: 'ShareModal');
      _showErrorSnackBar('Failed to share link');
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
    // Share link only (not vCard) - for generic "More" sharing
    await _shareLink();
  }

  void _showSuccessSnackBar(String message) {
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
                  Expanded(child: Text(message, style: AppTextStyles.body)),
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
                  Expanded(child: Text(message, style: AppTextStyles.body)),
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