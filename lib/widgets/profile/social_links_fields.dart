import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';

import '../../core/models/profile_models.dart';
import '../../theme/theme.dart';
import '../common/section_header_with_info.dart';
import 'form_field_builders.dart';

/// Widget that builds the social media fields based on the selected profile type.
///
/// This widget manages the social media platform selection and input fields,
/// displaying brand-colored chips for each available platform and a text field
/// for the selected platform.
///
/// Features:
/// - Horizontal scrollable chips for available social platforms
/// - Platform-specific brand colors and icons
/// - Visual indicator (green pill) for filled fields
/// - Auto-focus on platform selection
/// - Platform-specific prefixes (e.g., '@' for Instagram, 'linkedin.com/in/' for LinkedIn)
class SocialLinksFields extends StatefulWidget {
  final ProfileType profileType;
  final Map<String, TextEditingController> socialControllers;
  final Map<String, FocusNode> socialFocusNodes;
  final VoidCallback? onFormChanged;

  const SocialLinksFields({
    super.key,
    required this.profileType,
    required this.socialControllers,
    required this.socialFocusNodes,
    this.onFormChanged,
  });

  @override
  State<SocialLinksFields> createState() => _SocialLinksFieldsState();
}

class _SocialLinksFieldsState extends State<SocialLinksFields> {
  String? _selectedSocialPlatform;

  @override
  Widget build(BuildContext context) {
    final availableSocials = _getAvailableSocialPlatforms();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderWithInfo(
          title: 'Social Media',
          infoText: 'Add your social media profiles. Select a platform chip to enter your username or profile URL. A green indicator shows which platforms you\'ve filled in.',
        ),
        const SizedBox(height: 16),
        // Horizontal scrollable chips
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: availableSocials.length,
            itemBuilder: (context, index) {
              final social = availableSocials[index];
              final isSelected = _selectedSocialPlatform == social;
              final hasValue = widget.socialControllers[social]?.text.isNotEmpty ?? false;

              return Padding(
                padding: EdgeInsets.only(right: index < availableSocials.length - 1 ? 8 : 0),
                child: _buildSocialChip(social, isSelected, hasValue),
              );
            },
          ),
        ),
        // Show text field below if a platform is selected
        if (_selectedSocialPlatform != null) ...[
          const SizedBox(height: 16),
          GlassTextField(
            controller: widget.socialControllers[_selectedSocialPlatform]!,
            focusNode: widget.socialFocusNodes[_selectedSocialPlatform]!,
            nextFocusNode: null,
            label: _getSocialLabel(_selectedSocialPlatform!),
            icon: _getSocialIcon(_selectedSocialPlatform!),
            prefix: _getSocialPrefix(_selectedSocialPlatform!),
            textInputAction: TextInputAction.done,
            accentColor: _getSocialBrandColor(_selectedSocialPlatform!),
            showClearButton: true,
            onChanged: widget.onFormChanged,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// Build a social media chip with brand colors
  Widget _buildSocialChip(String social, bool isSelected, bool hasValue) {
    final brandColor = _getSocialBrandColor(social);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            // Toggle selection: if already selected, deselect; otherwise select
            _selectedSocialPlatform = isSelected ? null : social;
            // Focus the text field if selecting
            if (_selectedSocialPlatform != null) {
              Future.delayed(const Duration(milliseconds: 100), () {
                widget.socialFocusNodes[social]?.requestFocus();
              });
            }
          });
          HapticFeedback.lightImpact();
        },
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 60, // Fixed width for consistent sizing
              height: 54, // Fixed height
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? brandColor.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: brandColor.withValues(alpha: isSelected ? 0.6 : 0.4),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Centered icon takes up available space
                  Expanded(
                    child: Center(
                      child: Icon(
                        _getSocialIcon(social),
                        color: brandColor,
                        size: 22,
                      ),
                    ),
                  ),
                  // Green pill indicator at bottom - always present
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: hasValue
                          ? AppColors.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.5),
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

  /// Get available social platforms for the current profile type
  List<String> _getAvailableSocialPlatforms() {
    return ProfileData.getAvailableSocials(widget.profileType);
  }

  /// Get brand color for social platform (used in chips only)
  Color _getSocialBrandColor(String social) {
    switch (social.toLowerCase()) {
      case 'linkedin':
        return const Color(0xFF0077B5);
      case 'twitter':
      case 'x':
        return const Color(0xFF000000);
      case 'github':
        return const Color(0xFF333333);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'snapchat':
        return const Color(0xFFFFFC00);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'discord':
        return const Color(0xFF5865F2);
      case 'behance':
        return const Color(0xFF1769FF);
      case 'dribbble':
        return const Color(0xFFEA4C89);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'twitch':
        return const Color(0xFF9146FF);
      default:
        return AppColors.primaryAction;
    }
  }

  /// Get display label for social platform
  String _getSocialLabel(String social) {
    switch (social) {
      case 'instagram':
        return 'Instagram';
      case 'snapchat':
        return 'Snapchat';
      case 'tiktok':
        return 'TikTok';
      case 'twitter':
        return 'Twitter';
      case 'facebook':
        return 'Facebook';
      case 'linkedin':
        return 'LinkedIn';
      case 'github':
        return 'GitHub';
      case 'discord':
        return 'Discord';
      case 'behance':
        return 'Behance';
      case 'dribbble':
        return 'Dribbble';
      case 'youtube':
        return 'YouTube';
      case 'twitch':
        return 'Twitch';
      default:
        return social.toUpperCase();
    }
  }

  /// Get icon for social platform
  IconData _getSocialIcon(String social) {
    switch (social) {
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'snapchat':
        return FontAwesomeIcons.snapchat;
      case 'tiktok':
        return FontAwesomeIcons.tiktok;
      case 'twitter':
        return FontAwesomeIcons.xTwitter;
      case 'facebook':
        return FontAwesomeIcons.facebook;
      case 'linkedin':
        return FontAwesomeIcons.linkedin;
      case 'github':
        return FontAwesomeIcons.github;
      case 'discord':
        return FontAwesomeIcons.discord;
      case 'behance':
        return FontAwesomeIcons.behance;
      case 'dribbble':
        return FontAwesomeIcons.dribbble;
      case 'youtube':
        return FontAwesomeIcons.youtube;
      case 'twitch':
        return FontAwesomeIcons.twitch;
      default:
        return CupertinoIcons.link;
    }
  }

  /// Get prefix text for social platform input field
  String? _getSocialPrefix(String social) {
    switch (social) {
      case 'twitter':
      case 'instagram':
      case 'snapchat':
      case 'tiktok':
        return '@';
      case 'linkedin':
        return 'linkedin.com/in/';
      case 'github':
        return 'github.com/';
      case 'behance':
        return 'behance.net/';
      case 'dribbble':
        return 'dribbble.com/';
      default:
        return null;
    }
  }
}
