import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/theme.dart';

class ContactDetailModal extends StatefulWidget {
  final ContactCard contact;
  final VoidCallback? onSaved;
  final VoidCallback? onShared;

  const ContactDetailModal({
    Key? key,
    required this.contact,
    this.onSaved,
    this.onShared,
  }) : super(key: key);

  @override
  State<ContactDetailModal> createState() => _ContactDetailModalState();

  static Future<void> show(
    BuildContext context, {
    required ContactCard contact,
    VoidCallback? onSaved,
    VoidCallback? onShared,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => ContactDetailModal(
        contact: contact,
        onSaved: onSaved,
        onShared: onShared,
      ),
    );
  }
}

class _ContactDetailModalState extends State<ContactDetailModal>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  // Animations
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State
  bool _isAddingNote = false;
  bool _isSaving = false;
  String _noteText = '';
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _noteText = widget.contact.notes ?? '';
    _noteController.text = _noteText;
    _startAnimations();
  }

  void _initAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const Key('contact_detail_animated_builder'),
      animation: Listenable.merge([_scaleController, _fadeController]),
      builder: (context, child) {
        return Material(
          key: const Key('contact_detail_material'),
          color: Colors.transparent,
          child: Center(
            key: const Key('contact_detail_center'),
            child: FadeTransition(
              key: const Key('contact_detail_fade'),
              opacity: _fadeAnimation,
              child: Transform.scale(
                key: const Key('contact_detail_scale'),
                scale: _scaleAnimation.value,
                child: SlideTransition(
                  key: const Key('contact_detail_slide'),
                  position: _slideAnimation,
                  child: _buildModalContent(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalContent() {
    return Container(
      key: const Key('contact_detail_modal_container'),
      width: 320,
      height: 450,
      margin: const EdgeInsets.all(20),
      child: Stack(
        key: const Key('contact_detail_modal_stack'),
        children: [
          _buildMainCard(),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return ClipRRect(
      key: const Key('contact_detail_clip'),
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        key: const Key('contact_detail_backdrop'),
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          key: const Key('contact_detail_glass_container'),
          decoration: BoxDecoration(
            color: AppColors.glassBackground.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowDark.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.primaryAction.withOpacity(0.1),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            key: const Key('contact_detail_main_column'),
            children: [
              _buildHeader(),
              Expanded(
                key: const Key('contact_detail_expanded_content'),
                child: _buildContent(),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.glassBackground.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 1,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
      child: Column(
        children: [
          // Profile Photo
          Hero(
            tag: 'contact_${widget.contact.id}',
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryAction.withOpacity(0.3),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAction.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(37),
                child: widget.contact.profileImageUrl != null
                    ? Image.network(
                        widget.contact.profileImageUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.contact.name.isNotEmpty
                                ? widget.contact.name[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Name and Title
          Text(
            widget.contact.name,
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.contact.title != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.contact.title!,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (widget.contact.company != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.contact.company!,
              style: AppTextStyles.body.copyWith(
                color: AppColors.primaryAction,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContactInfo(),
          if (widget.contact.socialLinks.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSocialLinks(),
          ],
          if (_noteText.isNotEmpty || _isAddingNote) ...[
            const SizedBox(height: 20),
            _buildNotesSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.contact.email != null)
          _buildInfoRow(
            CupertinoIcons.mail,
            'Email',
            widget.contact.email!,
            () => _launchUrl('mailto:${widget.contact.email}'),
          ),
        if (widget.contact.phone != null)
          _buildInfoRow(
            CupertinoIcons.phone,
            'Phone',
            widget.contact.phone!,
            () => _launchUrl('tel:${widget.contact.phone}'),
          ),
        if (widget.contact.website != null)
          _buildInfoRow(
            CupertinoIcons.globe,
            'Website',
            widget.contact.website!,
            () => _launchUrl(widget.contact.website!),
          ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAction.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: AppColors.primaryAction,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        value,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.arrow_up_right_square,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Social Links',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.contact.socialLinks.map(_buildSocialChip).toList(),
        ),
      ],
    );
  }

  Widget _buildSocialChip(SocialLink link) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchUrl(link.url),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _getSocialColor(link.platform).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getSocialColor(link.platform).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getSocialIcon(link.platform),
                size: 16,
                color: _getSocialColor(link.platform),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  link.platform,
                  style: AppTextStyles.caption.copyWith(
                    color: _getSocialColor(link.platform),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Notes',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            if (!_isAddingNote)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _isAddingNote = true),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      CupertinoIcons.pencil,
                      size: 16,
                      color: AppColors.primaryAction,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isAddingNote)
          _buildNoteEditor()
        else if (_noteText.isNotEmpty)
          _buildNoteDisplay(),
      ],
    );
  }

  Widget _buildNoteEditor() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassBorder.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _noteController,
            maxLines: 3,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Add a note about this contact...',
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textTertiary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAddingNote = false;
                      _noteController.text = _noteText;
                    });
                  },
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saveNote,
                  child: Text(
                    'Save',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primaryAction,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glassBorder.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Text(
        _noteText,
        style: AppTextStyles.body.copyWith(
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: CupertinoIcons.person_add,
                  label: 'Save Contact',
                  onTap: _saveToContacts,
                  isPrimary: true,
                  isLoading: _isSaving,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: CupertinoIcons.share,
                  label: 'Share',
                  onTap: _shareContact,
                  isPrimary: false,
                ),
              ),
            ],
          ),
          if (!_isAddingNote && _noteText.isEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildActionButton(
                icon: CupertinoIcons.doc_text_fill,
                label: 'Add Note',
                onTap: () => setState(() => _isAddingNote = true),
                isPrimary: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.primaryAction.withOpacity(0.2)
                : AppColors.glassBorder.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? AppColors.primaryAction.withOpacity(0.5)
                  : AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPrimary
                          ? AppColors.primaryAction
                          : AppColors.textSecondary,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: isPrimary
                      ? AppColors.primaryAction
                      : AppColors.textSecondary,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: isPrimary
                      ? AppColors.primaryAction
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        HapticFeedback.lightImpact();
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      _showErrorSnackBar('Could not open link');
    }
  }

  Future<void> _saveToContacts() async {
    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      // Request contacts permission
      final permission = await Permission.contacts.request();
      if (permission != PermissionStatus.granted) {
        throw 'Contacts permission denied';
      }

      // Simulate saving to contacts
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        setState(() => _isSaving = false);
        _showSuccessSnackBar('Contact saved successfully');
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showErrorSnackBar('Failed to save contact: ${e.toString()}');
      }
    }
  }

  Future<void> _shareContact() async {
    try {
      HapticFeedback.lightImpact();
      // TODO: Implement contact sharing
      _showSuccessSnackBar('Contact shared successfully');
      widget.onShared?.call();
    } catch (e) {
      _showErrorSnackBar('Failed to share contact');
    }
  }

  void _saveNote() {
    setState(() {
      _noteText = _noteController.text;
      _isAddingNote = false;
    });
    HapticFeedback.lightImpact();
    _showSuccessSnackBar('Note saved');
  }

  IconData _getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'linkedin':
        return FontAwesomeIcons.linkedin;
      case 'twitter':
        return FontAwesomeIcons.xTwitter;
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'facebook':
        return FontAwesomeIcons.facebook;
      case 'github':
        return FontAwesomeIcons.github;
      default:
        return CupertinoIcons.link;
    }
  }

  Color _getSocialColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'linkedin':
        return const Color(0xFF0077B5);
      case 'twitter':
        return const Color(0xFF1DA1F2);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'github':
        return const Color(0xFF333333);
      default:
        return AppColors.primaryAction;
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success),
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_circle, color: AppColors.error),
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

// Data models
class ContactCard {
  final String id;
  final String name;
  final String? title;
  final String? company;
  final String? email;
  final String? phone;
  final String? website;
  final String? profileImageUrl;
  final List<SocialLink> socialLinks;
  final String? notes;
  final DateTime receivedAt;

  ContactCard({
    required this.id,
    required this.name,
    this.title,
    this.company,
    this.email,
    this.phone,
    this.website,
    this.profileImageUrl,
    this.socialLinks = const [],
    this.notes,
    required this.receivedAt,
  });

  ContactCard copyWith({
    String? notes,
  }) {
    return ContactCard(
      id: id,
      name: name,
      title: title,
      company: company,
      email: email,
      phone: phone,
      website: website,
      profileImageUrl: profileImageUrl,
      socialLinks: socialLinks,
      notes: notes ?? this.notes,
      receivedAt: receivedAt,
    );
  }
}

class SocialLink {
  final String platform;
  final String url;
  final String? displayName;

  SocialLink({
    required this.platform,
    required this.url,
    this.displayName,
  });
}