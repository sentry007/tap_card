import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../models/history_models.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/widgets.dart';

/// Modal bottom sheet showing detailed information about a history entry.
///
/// Features:
/// - Drag handle for dismissal
/// - Profile information with avatar
/// - Entry type and profile type badges
/// - Detailed information rows (method, device, location, time, tag info)
/// - Profile card preview for received entries
/// - Action buttons (Archive, Delete, Save to contacts)
/// - "View Card" button for received entries
///
/// Handles three entry types differently:
/// - Sent: Shows archive button
/// - Received: Shows profile card, delete and save buttons
/// - Tag: Shows tag information and delete button
class HistoryDetailModal extends StatelessWidget {
  final HistoryEntry item;
  final ScrollController scrollController;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final Function(dynamic profile) onSaveToContacts;
  final Function(String url) onLaunchUrl;
  final Function(String email) onLaunchEmail;
  final Function(String phone) onLaunchPhone;
  final Function(String platform, String url) onLaunchSocialMedia;

  const HistoryDetailModal({
    super.key,
    required this.item,
    required this.scrollController,
    required this.onArchive,
    required this.onDelete,
    required this.onSaveToContacts,
    required this.onLaunchUrl,
    required this.onLaunchEmail,
    required this.onLaunchPhone,
    required this.onLaunchSocialMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(
                color: _getModalBorderColor(item.type),
                width: 2.0,
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDragHandle(context),
                    const SizedBox(height: AppSpacing.lg),
                    _buildHeader(context),
                    const SizedBox(height: AppSpacing.lg),
                    _buildDetailRows(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildActions(context),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build drag handle with optional "View Card" button
  Widget _buildDragHandle(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Stack(
        children: [
          // Centered drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _getItemColor(item.type).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // View Card button (top-right) - ONLY for received entries
          if (item.type == HistoryEntryType.received && item.senderProfile?.id != null)
            Positioned(
              top: -2,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onLaunchUrl(
                      'https://atlaslinq.com/share/${item.senderProfile!.id}_${item.senderProfile!.type.name}'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Card',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.arrow_up_right_square,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build header with avatar, name, and badges
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _getItemColor(item.type).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildAvatar(),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.displayName,
                      style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Verified badge for received entries with metadata
                  if (item.type == HistoryEntryType.received && item.metadata?['has_metadata'] == true) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      size: 16,
                      color: AppColors.success,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildBadges(),
            ],
          ),
        ),
      ],
    );
  }

  /// Build type and profile badges
  Widget _buildBadges() {
    return Row(
      children: [
        // Entry type chip
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _getItemColor(item.type).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _getItemColor(item.type).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                item.type.label,
                style: AppTextStyles.caption.copyWith(
                  color: _getItemColor(item.type),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        // Profile type badge for received entries
        if (item.type == HistoryEntryType.received && item.senderProfile?.type != null) ...[
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getProfileTypeColor(item.senderProfile!.type).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _getProfileTypeColor(item.senderProfile!.type).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getProfileTypeIcon(item.senderProfile!.type),
                      size: 12,
                      color: _getProfileTypeColor(item.senderProfile!.type),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.senderProfile!.type.label,
                      style: AppTextStyles.caption.copyWith(
                        color: _getProfileTypeColor(item.senderProfile!.type),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Build detail rows (method, device, location, time, tag info)
  Widget _buildDetailRows() {
    return Column(
      children: [
        _buildDetailRow(
            CupertinoIcons.arrow_right_arrow_left, 'Method', item.method.label),
        if (item.recipientDevice != null)
          _buildDetailRow(CupertinoIcons.device_phone_portrait, 'Device',
              item.recipientDevice!),
        if (item.location != null)
          _buildDetailRow(CupertinoIcons.location_fill, 'Location', item.location!),
        // Debug: Show if location is missing for tag entries
        if (item.type == HistoryEntryType.tag && item.location == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              '⚠️ Location tracking disabled or permission denied',
              style: TextStyle(color: Colors.orange.withValues(alpha: 0.7), fontSize: 10),
            ),
          ),
        if (item.tagType != null)
          _buildDetailRow(CupertinoIcons.tag, 'Tag Info', _formatTagInfo(item)),
        // Show time for sent/tag always, and received IF we have real metadata
        if (item.type != HistoryEntryType.received ||
            item.metadata?['has_metadata'] == true)
          _buildDetailRow(
              CupertinoIcons.time, 'Time', _formatDetailTimestamp(item.timestamp)),
        // Show warning if no real timestamp for received entry
        if (item.type == HistoryEntryType.received &&
            item.metadata?['has_metadata'] != true)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              '⚠️ Estimated time (exact time not available)',
              style: TextStyle(color: Colors.orange.withValues(alpha: 0.7), fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Icon(
              icon,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons based on entry type
  Widget _buildActions(BuildContext context) {
    switch (item.type) {
      case HistoryEntryType.sent:
        return SizedBox(
          width: double.infinity,
          child: AppButton.outlined(
            text: 'Archive',
            icon: const Icon(CupertinoIcons.archivebox, size: 18),
            onPressed: onArchive,
          ),
        );

      case HistoryEntryType.received:
        return Column(
          children: [
            if (item.senderProfile != null) ...[
              _buildSenderProfileCard(context),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: AppButton.outlined(
                    text: 'Delete',
                    icon: const Icon(CupertinoIcons.delete, size: 18),
                    onPressed: onDelete,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton.contained(
                    text: 'Save',
                    icon: const Icon(CupertinoIcons.person_add, size: 18),
                    onPressed: () => onSaveToContacts(item.senderProfile!),
                  ),
                ),
              ],
            ),
          ],
        );

      case HistoryEntryType.tag:
        return SizedBox(
          width: double.infinity,
          child: AppButton.outlined(
            text: 'Delete',
            icon: const Icon(CupertinoIcons.delete, size: 18),
            onPressed: onDelete,
          ),
        );
    }
  }

  Widget _buildSenderProfileCard(BuildContext context) {
    final profile = item.senderProfile!;

    return Center(
      child: ProfileCardPreview(
        profile: profile,
        width: MediaQuery.of(context).size.width * 0.92,
        height: 180,
        borderRadius: AppRadius.xl,
        onEmailTap: profile.email != null ? () => onLaunchEmail(profile.email!) : null,
        onPhoneTap: profile.phone != null ? () => onLaunchPhone(profile.phone!) : null,
        onWebsiteTap:
            profile.website != null ? () => onLaunchUrl(profile.website!) : null,
        onSocialTap: (platform, url) => onLaunchSocialMedia(platform, url),
        onCustomLinkTap: (title, url) => onLaunchUrl(url),
      ),
    );
  }

  /// Placeholder avatar - actual implementation would need profile data
  Widget _buildAvatar() {
    // For now, return a simple colored circle
    // In the actual implementation, this would use the same logic as HistoryCard
    return Container(
      decoration: BoxDecoration(
        color: _getItemColor(item.type).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Icon(
        _getTypeIcon(item.type),
        color: _getItemColor(item.type),
        size: 28,
      ),
    );
  }

  // Helper methods
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

  Color _getModalBorderColor(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return AppColors.primaryAction.withValues(alpha: 0.5);
      case HistoryEntryType.received:
        return AppColors.success.withValues(alpha: 0.5);
      case HistoryEntryType.tag:
        return AppColors.secondaryAction.withValues(alpha: 0.5);
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

  Color _getProfileTypeColor(dynamic type) {
    final typeString = type.toString().split('.').last;
    switch (typeString) {
      case 'personal':
        return Colors.blue;
      case 'professional':
        return Colors.green;
      case 'custom':
        return Colors.purple;
      default:
        return AppColors.primaryAction;
    }
  }

  IconData _getProfileTypeIcon(dynamic type) {
    final typeString = type.toString().split('.').last;
    switch (typeString) {
      case 'personal':
        return CupertinoIcons.person;
      case 'professional':
        return CupertinoIcons.briefcase;
      case 'custom':
        return CupertinoIcons.star;
      default:
        return CupertinoIcons.person;
    }
  }

  String _formatTagInfo(HistoryEntry item) {
    final tagType = item.tagType ?? 'Unknown';
    final capacity = item.tagCapacity;
    final payloadType = item.payloadType;

    final parts = <String>[tagType];

    if (capacity != null) {
      parts.add('$capacity bytes');
    }

    if (payloadType != null) {
      final payloadLabel = payloadType == 'dual' ? 'Full card' : 'Mini card';
      parts.add(payloadLabel);
    }

    return parts.join(' • ');
  }

  String _formatDetailTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    // Today
    if (diff.inDays == 0 && timestamp.day == now.day) {
      final hour =
          timestamp.hour > 12 ? timestamp.hour - 12 : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return 'Today at $hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    }

    // Yesterday
    if (diff.inDays == 1 || (diff.inDays == 0 && timestamp.day != now.day)) {
      final hour =
          timestamp.hour > 12 ? timestamp.hour - 12 : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return 'Yesterday at $hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    }

    // This week
    if (diff.inDays < 7) {
      final weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][timestamp.weekday % 7];
      final hour =
          timestamp.hour > 12 ? timestamp.hour - 12 : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return '$weekday, $hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    }

    // This year
    if (timestamp.year == now.year) {
      final month = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][timestamp.month - 1];
      final hour =
          timestamp.hour > 12 ? timestamp.hour - 12 : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return '$month ${timestamp.day}, $hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    }

    // Older
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][timestamp.month - 1];
    return '$month ${timestamp.day}, ${timestamp.year}';
  }
}
