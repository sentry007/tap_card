import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'dart:io';

import '../../theme/theme.dart';
import '../../models/history_models.dart';
import '../../core/constants/app_constants.dart';
import 'method_chip.dart';

/// Individual history card widget with swipe-to-delete functionality.
///
/// Displays a history entry (sent/received/tag) with:
/// - Profile avatar or initial
/// - Entry name and details
/// - Method chip
/// - Location (if available)
/// - Timestamp
/// - Type indicator icon
///
/// Supports dismissible swipe-to-delete gesture.
class HistoryCard extends StatelessWidget {
  final HistoryEntry item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HistoryCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getHistoryColors(item.type);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: const Icon(CupertinoIcons.delete, color: AppColors.error, size: 24),
      ),
      confirmDismiss: (direction) async {
        // Call delete and wait for it to complete
        // onDelete callback handles the actual deletion and shows appropriate snackbar
        onDelete();
        // Return false to prevent automatic dismissal by Dismissible
        // The stream update from HistoryService will remove the item naturally,
        // avoiding widget tree conflicts while still providing visual feedback
        return false;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: colors['background'],
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: colors['border']!, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: _buildProfileAvatar(),
                          ),
                          const Spacer(),
                          // ✅ Orphaned card indicator (vCard deleted from device)
                          if (item.isOrphanedCard)
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              margin: const EdgeInsets.only(right: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: const Icon(
                                CupertinoIcons.exclamationmark_triangle,
                                color: AppColors.warning,
                                size: 12,
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: _getItemColor(item.type).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              _getTypeIcon(item.type),
                              color: _getItemColor(item.type),
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        item.displayName,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.subtitle,
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MethodChip(method: item.method, fontSize: 9, iconSize: 10),
                          if (item.location != null)
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(CupertinoIcons.location_fill, color: AppColors.textTertiary, size: 10),
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      item.location!,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textTertiary,
                                        fontSize: 9,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        _formatTimestamp(item.timestamp),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final radius = size / 2;
        final fontSize = size * 0.5;
        final iconSize = size * 0.6;

        switch (item.type) {
          case HistoryEntryType.sent:
            // Show recipient initial in circle
            final initial = item.recipientName?.isNotEmpty == true
                ? item.recipientName![0].toUpperCase()
                : '?';
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryAction,
                    AppColors.secondaryAction,
                  ],
                ),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );

          case HistoryEntryType.received:
            // Show sender's profile photo or initial
            final profile = item.senderProfile;
            if (profile == null) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Icon(CupertinoIcons.person, color: AppColors.success, size: iconSize),
              );
            }

            if (profile.profileImagePath != null && profile.profileImagePath!.isNotEmpty) {
              final isNetworkImage = profile.profileImagePath!.startsWith('http://') ||
                  profile.profileImagePath!.startsWith('https://');

              return ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: isNetworkImage
                    ? CachedNetworkImage(
                        imageUrl: profile.profileImagePath!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          CupertinoIcons.person,
                          color: AppColors.success,
                          size: iconSize,
                        ),
                      )
                    : Image.file(
                        File(profile.profileImagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            CupertinoIcons.person,
                            color: AppColors.success,
                            size: iconSize,
                          );
                        },
                      ),
              );
            }

            // Show initial in gradient
            final initial = profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?';
            return Container(
              decoration: BoxDecoration(
                gradient: profile.cardAesthetics.gradient,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );

          case HistoryEntryType.tag:
            // Show NFC tag icon with type badge
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.secondaryAction,
                        AppColors.highlight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.tag_fill,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                ),
                // Tag type badge (NTAG213/215/216)
                if (item.tagType != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.highlight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 0.5),
                      ),
                      child: Text(
                        item.tagType!.replaceAll('NTAG', ''),
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            );
        }
      },
    );
  }

  Map<String, Color> _getHistoryColors(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return {
          'background': AppColors.primaryAction.withValues(alpha: 0.1),
          'border': AppColors.primaryAction.withValues(alpha: 0.3),
        };
      case HistoryEntryType.received:
        return {
          'background': AppColors.success.withValues(alpha: 0.1),
          'border': AppColors.success.withValues(alpha: 0.3),
        };
      case HistoryEntryType.tag:
        return {
          'background': AppColors.secondaryAction.withValues(alpha: 0.1),
          'border': AppColors.secondaryAction.withValues(alpha: 0.3),
        };
    }
  }

  Color _getItemColor(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return AppColors.primaryAction;
      case HistoryEntryType.received:
        return AppColors.success;
      case HistoryEntryType.tag:
        return AppColors.secondaryAction;
    }
  }

  IconData _getTypeIcon(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return CupertinoIcons.arrow_up_right;
      case HistoryEntryType.received:
        return CupertinoIcons.arrow_down_left;
      case HistoryEntryType.tag:
        return CupertinoIcons.tag;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
