import 'dart:ui' as ui;
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For SynchronousFuture
import 'package:flutter/rendering.dart'; // For RenderRepaintBoundary
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/theme.dart';
import '../core/models/profile_models.dart';
import '../models/history_models.dart';
import '../services/qr_settings_service.dart';
import '../utils/snackbar_helper.dart';

class ShareModal extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? profileImageUrl;
  final VoidCallback? onNFCShare;
  final ProfileData profile;  // Full profile data for generating metadata
  final GlobalKey? profileCardKey;  // Key for capturing pre-rendered card from home screen

  const ShareModal({
    super.key,
    required this.userName,
    required this.userEmail,
    this.profileImageUrl,
    this.onNFCShare,
    required this.profile,
    this.profileCardKey,
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
    GlobalKey? profileCardKey,
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
        profileCardKey: profileCardKey,
      ),
    );
  }
}

class _ShareModalState extends State<ShareModal>
    with SingleTickerProviderStateMixin {
  // Animation controller (slide-in only)
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  // QR code capture key for export
  final GlobalKey _qrKey = GlobalKey();

  // Generated share data
  String _shareUrl = '';
  String _qrData = '';

  // QR settings
  QrSize _qrSize = QrSize.medium;
  int _errorCorrectionLevel = QrErrorCorrectLevel.M; // 0=L, 1=M, 2=Q, 3=H
  int _colorMode = 0;
  Color _borderColor = AppColors.p2pSecondary;
  bool _showLogo = true; // Show logo in QR by default
  QrLogoType _logoType = QrLogoType.atlasLogo; // Default to Atlas logo
  String _initials = ''; // User initials for QR
  int _payloadType = 0; // 0=vCard, 1=URL

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _initializeData();
    _startAnimation();
  }

  Future<void> _initializeData() async {
    await _loadQrSettings();
    _generateShareData();
  }

  Future<void> _loadQrSettings() async {
    await QrSettingsService.initialize();
    final size = await QrSettingsService.getQrSize();
    final errorLevel = await QrSettingsService.getErrorCorrectionLevel();
    final colorMode = await QrSettingsService.getColorMode();
    final borderColorValue = await QrSettingsService.getBorderColor();
    final showLogo = await QrSettingsService.getIncludeLogo();
    final logoType = await QrSettingsService.getQrLogoType();
    final payloadType = await QrSettingsService.getPayloadType();
    // Auto-extract initials from userName
    final initials = QrSettingsService.extractInitials(widget.userName);

    if (mounted) {
      setState(() {
        _qrSize = size;
        _errorCorrectionLevel = errorLevel;
        _colorMode = colorMode;
        _borderColor = borderColorValue != null ? Color(borderColorValue) : AppColors.p2pSecondary;
        _showLogo = showLogo;
        _logoType = logoType;
        _initials = initials;
        _payloadType = payloadType;
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

    // Generate QR code data based on payload type
    if (_payloadType == 1) {
      // URL mode: Use web link directly
      _qrData = _shareUrl;
      developer.log(
        '✅ Share data generated (URL mode)\n'
        '   • URL: $_shareUrl\n'
        '   • QR URL: ${_qrData.length} bytes',
        name: 'ShareModal'
      );
    } else {
      // vCard mode: Generate vCard WITH metadata (method: QR, fresh timestamp)
      final qrContext = ShareContext(
        method: ShareMethod.qr,
        timestamp: DateTime.now(),
      );
      final qrPayload = widget.profile.getDualPayloadWithContext(qrContext);
      _qrData = qrPayload['vcard']!;

      developer.log(
        '✅ Share data generated (vCard mode)\n'
        '   • URL: $_shareUrl\n'
        '   • QR vCard: ${_qrData.length} bytes (with X-TC metadata)',
        name: 'ShareModal'
      );
    }
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
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            key: const Key('share_modal_content_container'),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
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
                  color: AppColors.primaryAction.withValues(alpha: 0.3),
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
                  color: AppColors.glassBorder.withValues(alpha: 0.3),
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

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSectionDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.glassBorder.withValues(alpha: 0.3),
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
                color: AppColors.primaryAction.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
                      'Share to any app',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                CupertinoIcons.chevron_right,
                color: Colors.white.withValues(alpha: 0.7),
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
        RepaintBoundary(
          key: _qrKey,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowMedium.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: _qrSize.pixels.toDouble(),
              height: _qrSize.pixels.toDouble(),
              child: PrettyQrView.data(
                data: _qrData,
                errorCorrectLevel: _errorCorrectionLevel,
                decoration: PrettyQrDecoration(
                  shape: _colorMode == 1
                      ? PrettyQrSmoothSymbol(
                          color: _borderColor,
                        )
                      : const PrettyQrSmoothSymbol(
                          color: Colors.black,
                        ),
                  image: _showLogo ? _buildLogoImage() : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _payloadType == 1 ? 'Scan to open profile link' : 'Scan to save contact',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _shareQrCode,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.glassBorder.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.share,
                    size: 16,
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Share QR',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build logo image based on selected type
  PrettyQrDecorationImage? _buildLogoImage() {
    switch (_logoType) {
      case QrLogoType.atlasLogo:
        return const PrettyQrDecorationImage(
          image: AssetImage('assets/images/atlaslinq_logo_white.png'),
        );

      case QrLogoType.initials:
        if (_initials.isEmpty) return null;
        // Use a custom painter to render initials
        return PrettyQrDecorationImage(
          image: _buildInitialsImage(),
        );

      case QrLogoType.profileImage:
        if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty) {
          return PrettyQrDecorationImage(
            image: NetworkImage(widget.profileImageUrl!),
          );
        }
        // Fallback to Atlas logo if no profile image
        return const PrettyQrDecorationImage(
          image: AssetImage('assets/images/atlaslinq_logo_white.png'),
        );
    }
  }

  /// Build initials as an image using a custom image provider
  ImageProvider _buildInitialsImage() {
    // Use a custom painted image provider for initials
    return _InitialsImageProvider(_initials);
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
            color: AppColors.surfaceDark.withValues(alpha: 0.5),
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

  // ==================== SHARE CONTACT ====================

  /// Share contact with card image and rich URL message
  Future<void> _shareContactViaNearbyShare() async {
    try {
      HapticFeedback.mediumImpact();

      // Capture profile card as image
      developer.log('🔍 Attempting to capture card image...', name: 'ShareModal');
      developer.log('   • profileCardKey provided: ${widget.profileCardKey != null}', name: 'ShareModal');
      if (widget.profileCardKey != null) {
        final context = widget.profileCardKey?.currentContext;
        developer.log('   • Key has context: ${context != null}', name: 'ShareModal');
        if (context != null) {
          final renderObject = context.findRenderObject();
          developer.log('   • RenderObject found: ${renderObject != null}', name: 'ShareModal');
          developer.log('   • RenderObject type: ${renderObject.runtimeType}', name: 'ShareModal');
        }
      }

      final cardImage = await _captureProfileCardAsImage();

      if (cardImage != null) {
        // Build rich formatted message
        final message = _buildShareMessage();

        // Share card image + rich message via native share sheet
        await Share.shareXFiles(
          [cardImage],
          subject: '${widget.userName}\'s Contact',
          text: message,
        );
        developer.log('✅ Shared contact with card image + URL', name: 'ShareModal');
        _showSuccessSnackBar('Contact shared successfully');
      } else {
        developer.log('❌ Card image capture returned null', name: 'ShareModal');
        _showErrorSnackBar('Failed to create contact card');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Contact share failed: $e', name: 'ShareModal', error: e, stackTrace: stackTrace);
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

  /// Build rich formatted message based on profile type
  String _buildShareMessage() {
    final profile = widget.profile;
    final buffer = StringBuffer();

    switch (profile.type) {
      case ProfileType.personal:
        buffer.writeln('Check out ${profile.name}\'s contact!');
        buffer.writeln('');
        buffer.writeln('View profile: $_shareUrl');
        break;

      case ProfileType.professional:
        buffer.writeln(profile.name);
        if (profile.title != null && profile.title!.isNotEmpty) {
          buffer.write(profile.title);
          if (profile.company != null && profile.company!.isNotEmpty) {
            buffer.write(' at ${profile.company}');
          }
          buffer.writeln('');
        }

        final contactParts = <String>[];
        if (profile.phone != null && profile.phone!.isNotEmpty) {
          contactParts.add(profile.phone!);
        }
        if (profile.email != null && profile.email!.isNotEmpty) {
          contactParts.add(profile.email!);
        }
        if (contactParts.isNotEmpty) {
          buffer.writeln(contactParts.join(' | '));
        }

        buffer.writeln('');
        buffer.writeln('View full profile: $_shareUrl');
        break;

      case ProfileType.custom:
        buffer.writeln(profile.name);

        final contactParts = <String>[];
        if (profile.phone != null && profile.phone!.isNotEmpty) {
          contactParts.add(profile.phone!);
        }
        if (profile.email != null && profile.email!.isNotEmpty) {
          contactParts.add(profile.email!);
        }
        if (contactParts.isNotEmpty) {
          buffer.writeln(contactParts.join(' | '));
        }

        buffer.writeln('');
        buffer.writeln('View profile: $_shareUrl');
        break;
    }

    buffer.writeln('');
    buffer.write('Shared via Atlas Linq');

    return buffer.toString();
  }

  /// Capture profile card as image for sharing
  /// Uses the pre-rendered card from home screen (via GlobalKey) for efficiency
  Future<XFile?> _captureProfileCardAsImage() async {
    try {
      // Find the pre-rendered card boundary using the key
      final boundary = widget.profileCardKey?.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        developer.log('❌ Could not find profile card boundary', name: 'ShareModal');
        return null;
      }

      // Capture the already-rendered card as image with high quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        developer.log('❌ Could not convert card to bytes', name: 'ShareModal');
        return null;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Save to temp file
      final fileName = '${widget.userName.replaceAll(' ', '_')}_card.png';
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      developer.log(
        '✅ Profile card captured from pre-rendered boundary: ${pngBytes.length} bytes → $fileName',
        name: 'ShareModal'
      );

      return XFile(filePath, mimeType: 'image/png', name: fileName);
    } catch (e) {
      developer.log('❌ Card capture failed: $e', name: 'ShareModal');
      return null;
    }
  }

  /// Capture QR code as image and return file
  Future<XFile?> _captureQrCodeAsImage() async {
    try {
      // Find the render object
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        developer.log('❌ Could not find QR code boundary', name: 'ShareModal');
        return null;
      }

      // Capture the widget as an image with high quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        developer.log('❌ Could not convert QR code to bytes', name: 'ShareModal');
        return null;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Save to temp directory
      final fileName = '${widget.userName.replaceAll(' ', '_')}_QR.png';
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      developer.log(
        '✅ QR code captured as image: ${pngBytes.length} bytes → $fileName',
        name: 'ShareModal'
      );

      return XFile(filePath, mimeType: 'image/png', name: fileName);
    } catch (e) {
      developer.log('❌ Error capturing QR code: $e', name: 'ShareModal');
      return null;
    }
  }

  /// Share QR code with rich message
  Future<void> _shareQrCode() async {
    try {
      HapticFeedback.mediumImpact();

      final qrImage = await _captureQrCodeAsImage();

      if (qrImage != null) {
        // Build rich message based on payload type
        final message = _payloadType == 1
            ? 'Scan this QR code to visit ${widget.userName}\'s profile!\n\n$_shareUrl\n\nShared via Atlas Linq'
            : 'Scan this QR code to save ${widget.userName}\'s contact!\n\nShared via Atlas Linq';

        // Share QR code image with rich message
        await Share.shareXFiles(
          [qrImage],
          subject: '${widget.userName}\'s QR Code',
          text: message,
        );
        developer.log('✅ QR code shared with rich message', name: 'ShareModal');
      } else {
        _showErrorSnackBar('Failed to capture QR code');
      }
    } catch (e) {
      developer.log('❌ QR share failed: $e', name: 'ShareModal');
      _showErrorSnackBar('Failed to share QR code');
    }
  }

  void _showSuccessSnackBar(String message) {
    SnackbarHelper.showSuccess(
      context,
      message: message,
      icon: CupertinoIcons.checkmark_circle,
    );
  }

  void _showErrorSnackBar(String message) {
    SnackbarHelper.showError(
      context,
      message: message,
      icon: CupertinoIcons.exclamationmark_circle,
    );
  }

}

/// Custom ImageProvider for rendering initials as a circular image
class _InitialsImageProvider extends ImageProvider<_InitialsImageProvider> {
  final String initials;

  const _InitialsImageProvider(this.initials);

  @override
  Future<_InitialsImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_InitialsImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(_InitialsImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_loadAsync(key));
  }

  Future<ImageInfo> _loadAsync(_InitialsImageProvider key) async {
    const size = 200.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw simple initials text (no circular background)
    final textPainter = TextPainter(
      text: TextSpan(
        text: initials,
        style: const TextStyle(
          color: Colors.black,
          fontSize: size * 0.6,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    return ImageInfo(image: img);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _InitialsImageProvider && other.initials == initials;
  }

  @override
  int get hashCode => initials.hashCode;
}