import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import '../../services/profile_views_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/constants/routes.dart';

/// Activity Insights Widget
///
/// Displays a summary card of recent activity including:
/// - Cards sent in the last 7 days
/// - Cards received in the last 7 days
/// - Profile views this week (from Firestore)
/// - Total profile views
///
/// Tappable to navigate to the full insights screen.
class ActivityInsightsWidget extends StatelessWidget {
  const ActivityInsightsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Get active profile ID
    final profileService = ProfileService();
    final activeProfile = profileService.activeProfile;

    if (activeProfile == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<HistoryEntry>>(
      stream: HistoryService.historyStream(),
      builder: (context, historySnapshot) {
        if (!historySnapshot.hasData) {
          return const SizedBox.shrink();
        }

        // Stream view counts from Firestore (real-time)
        return StreamBuilder<Map<String, int>>(
          stream: ProfileViewsService.viewCountsStream(activeProfile.id),
          builder: (context, viewsSnapshot) {
            final viewCounts = viewsSnapshot.data ?? {'total': 0, 'thisWeek': 0};
            return _ActivityInsightsCard(
              history: historySnapshot.data!,
              viewsThisWeek: viewCounts['thisWeek'] ?? 0,
              viewsTotal: viewCounts['total'] ?? 0,
            );
          },
        );
      },
    );
  }
}

/// Internal widget that displays the insights card
class _ActivityInsightsCard extends StatelessWidget {
  final List<HistoryEntry> history;
  final int viewsThisWeek;
  final int viewsTotal;

  const _ActivityInsightsCard({
    required this.history,
    required this.viewsThisWeek,
    required this.viewsTotal,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate insights from last 7 days
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentHistory =
        history.where((e) => e.timestamp.isAfter(sevenDaysAgo)).toList();

    final receivedCount =
        recentHistory.where((e) => e.type == HistoryEntryType.received).length;
    final sentCount =
        recentHistory.where((e) => e.type == HistoryEntryType.sent).length;

    // Show empty state if no recent activity
    final hasRecentActivity = recentHistory.isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(AppRoutes.insights);
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryAction.withOpacity(0.08),
              AppColors.secondaryAction.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryAction.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: hasRecentActivity
            ? _buildActivityStats(sentCount, receivedCount, viewsThisWeek, viewsTotal)
            : _buildEmptyState(),
      ),
    );
  }

  Widget _buildActivityStats(int sentCount, int receivedCount, int viewsThisWeek, int viewsTotal) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stats Row
        Row(
          children: [
            Expanded(
              child: _InsightStat(
                value: sentCount.toString(),
                label: 'Sent',
                icon: CupertinoIcons.arrow_up_circle_fill,
                color: AppColors.primaryAction,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withOpacity(0.1),
            ),
            Expanded(
              child: _InsightStat(
                value: receivedCount.toString(),
                label: 'Received',
                icon: CupertinoIcons.arrow_down_circle_fill,
                color: AppColors.success,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withOpacity(0.1),
            ),
            Expanded(
              child: _InsightStat(
                value: viewsThisWeek.toString(),
                label: 'Views',
                icon: CupertinoIcons.eye_fill,
                color: AppColors.info,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withOpacity(0.1),
            ),
            Expanded(
              child: _InsightStat(
                value: _formatLargeNumber(viewsTotal),
                label: 'Total',
                icon: CupertinoIcons.chart_bar_circle_fill,
                color: AppColors.highlight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Hint Text
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.chart_bar_alt_fill,
              size: 12,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              'Tap for detailed analytics',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Format large numbers for display (e.g., 1000 -> 1k, 1500000 -> 1.5M)
  String _formatLargeNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(
          CupertinoIcons.chart_bar,
          size: 40,
          color: AppColors.textTertiary.withOpacity(0.6),
        ),
        const SizedBox(height: 12),
        Text(
          'Start sharing with AtlasLinq to see insights!',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.arrow_right_circle,
              size: 12,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              'Tap to explore',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Individual stat widget showing icon, value, and label
class _InsightStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _InsightStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
