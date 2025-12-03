import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:io';

import '../../theme/theme.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import '../../core/constants/routes.dart';
import '../widgets.dart';

/// Recent Connections Strip Widget
///
/// Displays a horizontal scrollable list of recent connections (received contacts).
/// Shows loading skeleton, empty states, and connection cards with profile pictures.
class RecentConnectionsWidget extends StatelessWidget {
  const RecentConnectionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('contacts-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeaderWithInfo(
            title: 'Recent Connections',
            infoText: 'People who have shared their digital cards with you via NFC, QR code, or web link. Tap any contact to view their full profile.',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          key: const Key('contacts-list'),
          height: 88,
          child: StreamBuilder<List<HistoryEntry>>(
            stream: HistoryService.historyStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _ContactsLoadingState();
              }

              if (snapshot.hasError) {
                return const _ContactsEmptyState();
              }

              final allHistory = snapshot.data ?? [];
              // Get only received entries with profile data (real connections)
              //
              // "Connections" = People who shared their contact info with you
              // This includes received cards via NFC, QR code, or web that have complete sender profile data
              final connections = allHistory
                  .where((e) =>
                      e.type == HistoryEntryType.received &&
                      e.senderProfile != null)
                  .take(10) // Show up to 10 recent connections
                  .toList();

              if (connections.isEmpty) {
                return const _ConnectionsEmptyState();
              }

              return _ConnectionsList(connections: connections);
            },
          ),
        ),
      ],
    );
  }
}

/// Loading skeleton for contacts
class _ContactsLoadingState extends StatelessWidget {
  const _ContactsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('home_contacts_loading_list'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16), // 8px * 2
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          key: Key('home_contacts_loading_item_$index'),
          width: 72, // 8px * 9
          margin: const EdgeInsets.only(right: 12),
          child: ClipRRect(
            key: Key('home_contacts_loading_clip_$index'),
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              key: Key('home_contacts_loading_backdrop_$index'),
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                key: Key('home_contacts_loading_container_$index'),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  key: Key('home_contacts_loading_column_$index'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      key: Key('home_contacts_loading_avatar_$index'),
                      width: 32, // 8px * 4
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(
                        key: Key('home_contacts_loading_spacing'), height: 8),
                    Container(
                      key: Key('home_contacts_loading_name_$index'),
                      width: 40, // 8px * 5
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Empty state for contacts (error state)
class _ContactsEmptyState extends StatelessWidget {
  const _ContactsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('home_contacts_empty_center'),
      child: Column(
        key: const Key('home_contacts_empty_column'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.person_2,
            key: Key('home_contacts_empty_icon'),
            color: AppColors.textTertiary,
            size: 24, // 8px * 3
          ),
          const SizedBox(key: Key('home_contacts_empty_spacing'), height: 8),
          Text(
            'No recent contacts',
            key: const Key('home_contacts_empty_text'),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state when no connections have been received yet
class _ConnectionsEmptyState extends StatelessWidget {
  const _ConnectionsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.person_2_fill,
            color: AppColors.textTertiary,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'No connections yet',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Receive a card to see connections',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scrollable list of connection cards
class _ConnectionsList extends StatelessWidget {
  final List<HistoryEntry> connections;

  const _ConnectionsList({required this.connections});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final entry = connections[index];
        return ConnectionCard(entry: entry, index: index);
      },
    );
  }
}

/// Individual connection card widget
///
/// Displays a contact with their profile picture/initials, name, and time ago.
/// Tappable to navigate to history detail.
class ConnectionCard extends StatelessWidget {
  final HistoryEntry entry;
  final int index;

  const ConnectionCard({
    super.key,
    required this.entry,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final profile = entry.senderProfile!;
    final hasImage = profile.profileImagePath != null &&
        profile.profileImagePath!.isNotEmpty;
    final initials = _getInitials(profile.name);
    final methodColor = _getMethodColor(entry.method);
    final timeAgo = _formatTimeAgo(entry.timestamp);

    return Container(
      key: Key('connection_card_$index'),
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  methodColor.withValues(alpha: 0.15),
                  methodColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: methodColor.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('${AppRoutes.history}?entryId=${entry.id}');
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile picture or initials
                      hasImage
                          ? Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: methodColor,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16.5),
                                child: _buildProfileImage(
                                  profile.profileImagePath!,
                                  initials,
                                  methodColor,
                                ),
                              ),
                            )
                          : _buildInitialsCircle(initials, methodColor),
                      const SizedBox(height: 6),
                      // Name (first name only)
                      Text(
                        profile.name.split(' ').first,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      // Time ago
                      Text(
                        timeAgo,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 8,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
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

  /// Build profile image widget with error fallback
  Widget _buildProfileImage(String imagePath, String initials, Color color) {
    // Check if it's a local file path or network URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialsCircle(initials, color);
        },
      );
    } else {
      // Local file
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsCircle(initials, color);
          },
        );
      } else {
        return _buildInitialsCircle(initials, color);
      }
    }
  }

  /// Build initials circle widget
  Widget _buildInitialsCircle(String initials, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Get initials from a name (first and last initial)
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  /// Get color based on share method
  Color _getMethodColor(ShareMethod method) {
    switch (method) {
      case ShareMethod.nfc:
        return AppColors.primaryAction; // Orange
      case ShareMethod.qr:
        return AppColors.secondaryAction; // Purple
      case ShareMethod.web:
        return AppColors.highlight; // Yellow
      case ShareMethod.tag:
        return AppColors.success; // Green
      case ShareMethod.quickShare:
        return AppColors.quickSharePrimary; // Blue
    }
  }

  /// Format time ago string (e.g., "2h ago", "5m ago")
  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
