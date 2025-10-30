import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:io';

import '../../theme/theme.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import '../../core/constants/routes.dart';

/// Frequent Contacts Widget
///
/// Displays a horizontal scrollable list of frequently contacted people.
/// Shows loading skeleton, empty states, and contact cards with profile pictures and frequency badges.
///
/// Features:
/// - Automatically calculates frequent contacts (2+ interactions)
/// - Shows top 5 most frequent contacts
/// - Contact sync button integration
/// - Profile pictures with frequency badges
class FrequentContactsWidget extends StatelessWidget {
  final bool isSyncingContacts;
  final VoidCallback onSyncTap;

  const FrequentContactsWidget({
    super.key,
    required this.isSyncingContacts,
    required this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryEntry>>(
      stream: HistoryService.historyStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final allHistory = snapshot.data!;

        // Count frequency of each contact based on received entries
        final frequencyMap = <String, FrequentContactData>{};

        for (final entry in allHistory) {
          if (entry.type == HistoryEntryType.received &&
              entry.senderProfile != null) {
            final name = entry.senderProfile!.name;
            if (frequencyMap.containsKey(name)) {
              frequencyMap[name]!.count++;
              // Keep the most recent entry
              if (entry.timestamp
                  .isAfter(frequencyMap[name]!.lastEntry.timestamp)) {
                frequencyMap[name]!.lastEntry = entry;
              }
            } else {
              frequencyMap[name] = FrequentContactData(
                lastEntry: entry,
                count: 1,
              );
            }
          }
        }

        // Filter contacts with at least 2 interactions and sort by frequency
        final frequentContacts = frequencyMap.values
            .where((data) => data.count >= 2)
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));

        // Show nothing if no frequent contacts
        if (frequentContacts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Take top 5
        final topContacts = frequentContacts.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Frequent Contacts',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryAction.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${topContacts.length}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.secondaryAction,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Sync device contacts button
                  _SyncButton(
                    isSyncing: isSyncingContacts,
                    onTap: onSyncTap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'People you interact with most',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 88,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: topContacts.length,
                itemBuilder: (context, index) {
                  final data = topContacts[index];
                  return _FrequentContactCard(data: data, index: index);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Sync button widget
class _SyncButton extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback onTap;

  const _SyncButton({
    required this.isSyncing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSyncing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.info.withOpacity(0.2),
              AppColors.info.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.info.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                ),
              )
            else
              const Icon(
                Icons.sync,
                size: 14,
                color: AppColors.info,
              ),
            const SizedBox(width: 4),
            Text(
              isSyncing ? 'Syncing...' : 'Sync',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual frequent contact card widget
class _FrequentContactCard extends StatelessWidget {
  final FrequentContactData data;
  final int index;

  const _FrequentContactCard({
    required this.data,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final entry = data.lastEntry;
    final profile = entry.senderProfile!;
    final hasImage = profile.profileImagePath != null &&
        profile.profileImagePath!.isNotEmpty;
    final initials = _getInitials(profile.name);

    return Container(
      key: Key('frequent_contact_card_$index'),
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
                  AppColors.secondaryAction.withOpacity(0.15),
                  AppColors.secondaryAction.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondaryAction.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile picture or initials with count badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          hasImage
                              ? Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.secondaryAction,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: _buildProfileImage(
                                      profile.profileImagePath!,
                                      initials,
                                    ),
                                  ),
                                )
                              : _buildInitialsCircle(
                                  initials, AppColors.secondaryAction),
                          // Frequency badge
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryAction,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryBackground,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${data.count}',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Name (first name only)
                      Text(
                        profile.name.split(' ').first,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
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
  Widget _buildProfileImage(String imagePath, String initials) {
    // Check if it's a local file path or network URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialsCircle(initials, AppColors.secondaryAction);
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
            return _buildInitialsCircle(initials, AppColors.secondaryAction);
          },
        );
      } else {
        return _buildInitialsCircle(initials, AppColors.secondaryAction);
      }
    }
  }

  /// Build initials circle widget
  Widget _buildInitialsCircle(String initials, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
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
}

/// Helper class for tracking frequent contacts
class FrequentContactData {
  HistoryEntry lastEntry;
  int count;

  FrequentContactData({
    required this.lastEntry,
    required this.count,
  });
}
