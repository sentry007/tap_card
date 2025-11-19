import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/theme.dart';
import '../../core/services/profile_service.dart';
import '../../widgets/common/profile_card_preview.dart';

/// Profile Preview Widget
///
/// Displays a preview of the active profile card with interactive elements.
/// Shows either the card preview or a "No Profile Found" state.
///
/// Features:
/// - Interactive card preview using ProfileCardPreview
/// - Tap handlers for email, phone, website, social media
/// - URL launching for all contact methods
/// - Optional cardKey for capturing rendered card as image
class ProfilePreviewWidget extends StatelessWidget {
  final ProfileService profileService;
  final GlobalKey? cardKey; // Optional key for image capture

  const ProfilePreviewWidget({
    super.key,
    required this.profileService,
    this.cardKey,
  });

  @override
  Widget build(BuildContext context) {
    final activeProfile = profileService.activeProfile;

    if (activeProfile == null) {
      return _buildNoProfileState();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: RepaintBoundary(
        key: cardKey,
        child: ProfileCardPreview(
          profile: activeProfile,
          width: double.infinity,
          height: 180,
          borderRadius: 20,
          showProfileTypeChip: true,
          onEmailTap: activeProfile.email != null
              ? () => _launchEmail(activeProfile.email!)
              : null,
          onPhoneTap: activeProfile.phone != null
              ? () => _launchPhone(activeProfile.phone!)
              : null,
          onWebsiteTap: activeProfile.website != null
              ? () => _launchUrl(activeProfile.website!)
              : null,
          onSocialTap: (platform, url) => _launchSocialMedia(platform, url),
          onCustomLinkTap: (title, url) => _launchUrl(url),
        ),
      ),
    );
  }

  Widget _buildNoProfileState() {
    return Container(
      key: const Key('home_card_preview_loading'),
      width: 300,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
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

  // URL launching methods
  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    await launchUrl(uri);
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Future<void> _launchUrl(String url) async {
    // Add https:// if no protocol specified
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }

    final uri = Uri.parse(finalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _launchSocialMedia(String platform, String url) async {
    // For social media, we use the URL directly
    // The URL is already formatted correctly in the profile data
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }

    await _launchUrl(finalUrl);
  }
}

/// Preview Mode Text Widget
///
/// Displays explanatory text when in preview mode.
class ProfilePreviewTextWidget extends StatelessWidget {
  const ProfilePreviewTextWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(
          key: Key('home_preview_subtitle_spacing'),
          height: 8,
        ),
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
}
