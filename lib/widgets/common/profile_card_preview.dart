import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'dart:io';
import '../../theme/theme.dart';
import '../../core/models/profile_models.dart';
import '../../utils/logger.dart';

/// Reusable profile card preview widget
///
/// Displays a glassmorphic card with profile information
/// Used in: home screen preview, history received items, contact details
class ProfileCardPreview extends StatelessWidget {
  final ProfileData profile;
  final double width;
  final double height;
  final double borderRadius;
  final bool showBorder;
  final VoidCallback? onEmailTap;
  final VoidCallback? onPhoneTap;
  final VoidCallback? onWebsiteTap;
  final Function(String platform, String url)? onSocialTap;
  final Function(String title, String url)? onCustomLinkTap;
  final VoidCallback? onProfileImageTap;
  final bool showProfileTypeChip;

  const ProfileCardPreview({
    super.key,
    required this.profile,
    this.width = 300,
    this.height = 180,
    this.borderRadius = 20,
    this.showBorder = true,
    this.onEmailTap,
    this.onPhoneTap,
    this.onWebsiteTap,
    this.onSocialTap,
    this.onCustomLinkTap,
    this.onProfileImageTap,
    this.showProfileTypeChip = false,
  });

  /// Helper method to build image from either local file or network URL
  Widget _buildImage(
    String imagePath, {
    required BoxFit fit,
  }) {
    final isNetworkImage = imagePath.startsWith('http://') || imagePath.startsWith('https://');

    if (isNetworkImage) {
      Logger.debug('Loading network image: $imagePath', name: 'ProfileCardPreview');
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: fit,
        placeholder: (context, url) {
          Logger.debug('Loading image...', name: 'ProfileCardPreview');
          return Container(
            color: Colors.grey.withValues(alpha: 0.2),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorWidget: (context, url, error) {
          Logger.error('Image load failed: $error\n  URL: $url', name: 'ProfileCardPreview', error: error);
          return Container(
            color: Colors.grey.withValues(alpha: 0.2),
            child: const Icon(Icons.error_outline, color: Colors.red),
          );
        },
      );
    } else {
      Logger.debug('Loading local file: $imagePath', name: 'ProfileCardPreview');
      return Image.file(
        File(imagePath),
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          Logger.error('Local file load failed: $error', name: 'ProfileCardPreview', error: error);
          return Container(
            color: Colors.grey.withValues(alpha: 0.2),
            child: const Icon(Icons.broken_image, color: Colors.red),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final aesthetics = profile.cardAesthetics;

    return IntrinsicHeight(
      child: Container(
        width: width,
        constraints: BoxConstraints(minHeight: height),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                children: [
              // Background with profile colors
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: aesthetics.backgroundColor != null
                      ? LinearGradient(
                          colors: [
                            aesthetics.backgroundColor!,
                            aesthetics.backgroundColor!.withValues(alpha: 0.8),
                          ],
                        )
                      : aesthetics.gradient,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),

            // Background image if present
            if (aesthetics.hasBackgroundImage)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: _buildImage(
                    aesthetics.backgroundImagePath!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Glassmorphic overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: aesthetics.blurLevel,
                  sigmaY: aesthetics.blurLevel,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: aesthetics.hasBackgroundImage ? 0.1 : 0.2),
                        Colors.white.withValues(alpha: aesthetics.hasBackgroundImage ? 0.05 : 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: showBorder && aesthetics.borderColor != Colors.transparent
                      ? Border.all(
                          color: aesthetics.borderColor.withValues(alpha: 0.8),
                          width: 1.5,
                        )
                      : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Content overlay for readability
            if (aesthetics.hasBackgroundImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),

            // Actual content
            Container(
              padding: EdgeInsets.all(height * 0.11), // Proportional padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with avatar and name
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onProfileImageTap,
                        child: Stack(
                          children: [
                            Container(
                              width: height * 0.25, // Proportional avatar size
                              height: height * 0.25,
                              decoration: BoxDecoration(
                                gradient: profile.profileImagePath != null
                                  ? null
                                  : aesthetics.gradient,
                                borderRadius: BorderRadius.circular(height * 0.125),
                              ),
                              child: profile.profileImagePath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(height * 0.125),
                                    child: Builder(
                                      builder: (context) {
                                        Logger.debug(
                                          'Rendering profile image\n'
                                          '  Image path: ${profile.profileImagePath}\n'
                                          '  Is network URL: ${profile.profileImagePath!.startsWith('http')}',
                                          name: 'ProfileCardPreview',
                                        );

                                        return _buildImage(
                                          profile.profileImagePath!,
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    CupertinoIcons.person,
                                    color: Colors.white,
                                    size: height * 0.13,
                                  ),
                            ),
                            // Edit icon overlay (only show if tappable)
                            if (onProfileImageTap != null)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: height * 0.08,
                                  height: height * 0.08,
                                  decoration: BoxDecoration(
                                    color: aesthetics.borderColor != Colors.transparent
                                        ? aesthetics.borderColor
                                        : AppColors.primaryAction,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.camera_fill,
                                    color: Colors.white,
                                    size: height * 0.045,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: height * 0.067),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              profile.name.isNotEmpty ? profile.name : 'No Name',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: height * 0.089,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            SizedBox(height: height * 0.011),
                            if (profile.title != null && profile.title!.isNotEmpty)
                              Text(
                                profile.title!,
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: height * 0.067,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.089),

                  // Contact info
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        if (profile.email != null && profile.email!.isNotEmpty)
                          _buildContactRow(
                            CupertinoIcons.mail,
                            profile.email!,
                            height,
                            onTap: onEmailTap,
                          ),
                        if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                          SizedBox(height: height * 0.033),
                          _buildContactRow(
                            CupertinoIcons.phone,
                            profile.phone!,
                            height,
                            onTap: onPhoneTap,
                          ),
                        ],
                        if (profile.company != null && profile.company!.isNotEmpty) ...[
                          SizedBox(height: height * 0.033),
                          _buildContactRow(
                            CupertinoIcons.briefcase,
                            profile.company!,
                            height,
                            onTap: onWebsiteTap,
                          ),
                        ],
                        // Social media icons
                        if (profile.socialMedia.isNotEmpty && onSocialTap != null) ...[
                          SizedBox(height: height * 0.025),
                          _buildSocialIcons(height),
                        ],
                        // Custom links icons
                        if (profile.customLinks.isNotEmpty && onCustomLinkTap != null) ...[
                          SizedBox(height: height * 0.015),
                          _buildCustomLinkIcons(height),
                        ],
                      ],
                    ),
                ],
              ),
            ),
                ],
              ),
            ),

            // Profile type chip (top right) - ONLY if showProfileTypeChip is true
            // Positioned OUTSIDE ClipRRect to appear on top without being clipped
            if (showProfileTypeChip)
              Positioned(
                top: 12,
                right: 12,
                child: _buildProfileTypeChip(height),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text, double height, {VoidCallback? onTap}) {
    final row = Row(
      children: [
        Icon(
          icon,
          size: height * 0.078,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        SizedBox(width: height * 0.033),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: height * 0.061,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (onTap != null)
          Icon(
            CupertinoIcons.arrow_right,
            size: height * 0.056,
            color: Colors.white.withValues(alpha: 0.5),
          ),
      ],
    );

    if (onTap == null) {
      return row;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: row,
        ),
      ),
    );
  }

  Widget _buildSocialIcons(double height) {
    final iconSize = height * 0.12; // 24px for 200px height
    final socialEntries = profile.socialMedia.entries.toList();
    const maxVisible = 6;
    final visibleSocials = socialEntries.take(maxVisible).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...visibleSocials.map((entry) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildSocialIcon(entry.key, entry.value, iconSize),
        )),
        if (socialEntries.length > maxVisible)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '+${socialEntries.length - maxVisible}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: iconSize * 0.75,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSocialIcon(String platform, String url, double size) {
    final iconData = _getSocialIconData(platform);
    // Use card border color instead of brand colors for a more cohesive look
    final iconColor = profile.cardAesthetics.borderColor != Colors.transparent
        ? profile.cardAesthetics.borderColor
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSocialTap?.call(platform, url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            iconData['icon'],
            color: iconColor.withValues(alpha: 0.9),
            size: size * 0.8,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getSocialIconData(String platform) {
    switch (platform.toLowerCase()) {
      case 'linkedin':
        return {'icon': FontAwesomeIcons.linkedin, 'color': const Color(0xFF0077B5)};
      case 'twitter':
      case 'x':
        return {'icon': FontAwesomeIcons.xTwitter, 'color': const Color(0xFF000000)};
      case 'github':
        return {'icon': FontAwesomeIcons.github, 'color': const Color(0xFF333333)};
      case 'instagram':
        return {'icon': FontAwesomeIcons.instagram, 'color': const Color(0xFFE4405F)};
      case 'snapchat':
        return {'icon': FontAwesomeIcons.snapchat, 'color': const Color(0xFFFFFC00)};
      case 'facebook':
        return {'icon': FontAwesomeIcons.facebook, 'color': const Color(0xFF1877F2)};
      case 'discord':
        return {'icon': FontAwesomeIcons.discord, 'color': const Color(0xFF5865F2)};
      case 'behance':
        return {'icon': FontAwesomeIcons.behance, 'color': const Color(0xFF1769FF)};
      case 'dribbble':
        return {'icon': FontAwesomeIcons.dribbble, 'color': const Color(0xFFEA4C89)};
      case 'tiktok':
        return {'icon': FontAwesomeIcons.tiktok, 'color': const Color(0xFF000000)};
      case 'youtube':
        return {'icon': FontAwesomeIcons.youtube, 'color': const Color(0xFFFF0000)};
      case 'twitch':
        return {'icon': FontAwesomeIcons.twitch, 'color': const Color(0xFF9146FF)};
      default:
        return {'icon': CupertinoIcons.link, 'color': AppColors.primaryAction};
    }
  }

  Widget _buildCustomLinkIcons(double height) {
    final iconSize = height * 0.12; // Same size as social icons

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: profile.customLinks.map((link) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildCustomLinkIcon(link, iconSize),
        )
      ).toList(),
    );
  }

  Widget _buildCustomLinkIcon(CustomLink link, double size) {
    // Use card border color instead of brand colors for a more cohesive look
    final iconColor = profile.cardAesthetics.borderColor != Colors.transparent
        ? profile.cardAesthetics.borderColor
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onCustomLinkTap?.call(link.title, link.url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            CupertinoIcons.link,
            color: iconColor.withValues(alpha: 0.9),
            size: size * 0.8,
          ),
        ),
      ),
    );
  }

  /// Build profile type chip for top-right corner
  Widget _buildProfileTypeChip(double height) {
    final chipData = _getProfileTypeData();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: height * 0.055,
            vertical: height * 0.03,
          ),
          decoration: BoxDecoration(
            color: chipData['color'].withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: chipData['color'].withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                chipData['icon'] as IconData,
                size: height * 0.067,
                color: Colors.white,
              ),
              SizedBox(width: height * 0.028),
              Text(
                profile.type.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: height * 0.061,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get profile type icon and color
  Map<String, dynamic> _getProfileTypeData() {
    switch (profile.type) {
      case ProfileType.personal:
        return {'icon': CupertinoIcons.person, 'color': Colors.blue};
      case ProfileType.professional:
        return {'icon': CupertinoIcons.briefcase, 'color': Colors.green};
      case ProfileType.custom:
        return {'icon': CupertinoIcons.star, 'color': Colors.purple};
    }
  }
}
