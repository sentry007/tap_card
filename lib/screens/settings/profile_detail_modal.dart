/// Profile Detail Modal
///
/// Displays full profile information in a glassmorphic modal
/// Shown when user taps their profile header in settings
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/models/profile_models.dart';
import '../../core/constants/app_constants.dart';

class ProfileDetailModal extends StatelessWidget {
  final ProfileData profile;

  const ProfileDetailModal({
    super.key,
    required this.profile,
  });

  static void show(BuildContext context, ProfileData profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ProfileDetailModal(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Profile content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile header with image
                        Center(
                          child: Column(
                            children: [
                              // Profile image
                              Hero(
                                tag: 'profile_image_${profile.id}',
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(50),
                                    border: Border.all(
                                      color: profile.cardAesthetics.primaryColor.withOpacity(0.5),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: profile.cardAesthetics.primaryColor.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: profile.profileImagePath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(47),
                                          child: Image.network(
                                            profile.profileImagePath!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                                          ),
                                        )
                                      : _buildDefaultAvatar(),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),

                              // Name
                              Text(
                                profile.name,
                                style: AppTextStyles.h2.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xs),

                              // Profile type badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: profile.cardAesthetics.primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: profile.cardAesthetics.primaryColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getProfileTypeIcon(profile.type),
                                      size: 14,
                                      color: profile.cardAesthetics.primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile.type.label,
                                      style: AppTextStyles.caption.copyWith(
                                        color: profile.cardAesthetics.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),
                        const Divider(color: AppColors.glassBorder),
                        const SizedBox(height: AppSpacing.lg),

                        // Contact information
                        Text(
                          'Contact Information',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        if (profile.email != null && profile.email!.isNotEmpty)
                          _buildInfoRow(
                            CupertinoIcons.mail,
                            'Email',
                            profile.email!,
                          ),
                        if (profile.phone != null && profile.phone!.isNotEmpty)
                          _buildInfoRow(
                            CupertinoIcons.phone,
                            'Phone',
                            profile.phone!,
                          ),
                        if (profile.company != null && profile.company!.isNotEmpty)
                          _buildInfoRow(
                            CupertinoIcons.building_2_fill,
                            'Company',
                            profile.company!,
                          ),
                        if (profile.title != null && profile.title!.isNotEmpty)
                          _buildInfoRow(
                            CupertinoIcons.briefcase,
                            'Title',
                            profile.title!,
                          ),
                        if (profile.website != null && profile.website!.isNotEmpty)
                          _buildInfoRow(
                            CupertinoIcons.globe,
                            'Website',
                            profile.website!,
                          ),

                        // Social media links
                        if (profile.socialMedia.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(color: AppColors.glassBorder),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Social Media',
                            style: AppTextStyles.h3.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ...profile.socialMedia.entries.map(
                            (entry) => _buildInfoRow(
                              _getSocialIcon(entry.key),
                              _formatSocialKey(entry.key),
                              entry.value,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Action buttons
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppColors.glassBorder.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton.outlined(
                          text: 'Close',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navigate to profile screen
                            // context.go('/profile');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(CupertinoIcons.pencil, size: 18, color: Colors.white),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Edit Profile',
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom safe area padding
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            profile.cardAesthetics.primaryColor,
            profile.cardAesthetics.secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(47),
      ),
      child: const Center(
        child: Icon(
          CupertinoIcons.person_fill,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProfileTypeIcon(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return CupertinoIcons.person_fill;
      case ProfileType.professional:
        return CupertinoIcons.briefcase_fill;
      case ProfileType.custom:
        return CupertinoIcons.star_fill;
    }
  }

  IconData _getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return CupertinoIcons.camera;
      case 'twitter':
        return CupertinoIcons.chat_bubble_text;
      case 'linkedin':
        return CupertinoIcons.briefcase;
      case 'facebook':
        return CupertinoIcons.person_2;
      case 'github':
        return CupertinoIcons.command;
      case 'youtube':
        return CupertinoIcons.play_rectangle;
      default:
        return CupertinoIcons.link;
    }
  }

  String _formatSocialKey(String key) {
    return key.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
