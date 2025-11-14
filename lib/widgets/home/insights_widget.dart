import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import '../../services/profile_performance_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/constants/routes.dart';

/// Activity Insights Widget
///
/// Displays a summary card of recent activity including:
/// - Cards sent in the last 7 days
/// - Cards received in the last 7 days
/// - Total profile views across all profiles
/// - Most viewed profile type
///
/// Tappable to navigate to the full insights screen.
class ActivityInsightsWidget extends StatelessWidget {
  const ActivityInsightsWidget({super.key});

  Future<Map<String, dynamic>> _getViewStats() async {
    final profileService = ProfileService();
    final profiles = profileService.profiles;

    if (profiles.isEmpty) {
      return {'totalViews': 0, 'topProfile': '---'};
    }

    try {
      final stats = await ProfilePerformanceService.getAllProfileStats(profiles);
      final totalViews = stats.fold<int>(0, (total, stat) => total + stat.viewCount);
      final topStat = stats.isNotEmpty && stats.first.viewCount > 0 ? stats.first : null;

      return {
        'totalViews': totalViews,
        'topProfile': topStat?.type.label ?? '---',
      };
    } catch (e) {
      return {'totalViews': 0, 'topProfile': '---'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryEntry>>(
      stream: HistoryService.historyStream(),
      builder: (context, historySnapshot) {
        if (!historySnapshot.hasData) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _getViewStats(),
          builder: (context, viewsSnapshot) {
            final viewsData = viewsSnapshot.data ?? {'totalViews': 0, 'topProfile': '---'};
            final isLoadingViews = !viewsSnapshot.hasData;

            return _ActivityInsightsCard(
              history: historySnapshot.data!,
              totalViews: viewsData['totalViews'] as int,
              topProfile: viewsData['topProfile'] as String,
              isLoadingViews: isLoadingViews,
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
  final int totalViews;
  final String topProfile;
  final bool isLoadingViews;

  const _ActivityInsightsCard({
    required this.history,
    required this.totalViews,
    required this.topProfile,
    required this.isLoadingViews,
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

    // Show stats if there's recent activity OR profile views
    final hasActivity = recentHistory.isNotEmpty || totalViews > 0;

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
              AppColors.primaryAction.withValues(alpha: 0.08),
              AppColors.secondaryAction.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryAction.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: hasActivity
            ? _buildActivityStats(sentCount, receivedCount)
            : _buildEmptyState(),
      ),
    );
  }

  Widget _buildActivityStats(int sentCount, int receivedCount) {
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
              color: Colors.white.withValues(alpha: 0.1),
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
              color: Colors.white.withValues(alpha: 0.1),
            ),
            Expanded(
              child: _InsightStat(
                value: isLoadingViews ? '...' : _formatLargeNumber(totalViews),
                label: 'Views',
                icon: CupertinoIcons.eye_fill,
                color: AppColors.info,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            Expanded(
              child: _InsightStat(
                value: isLoadingViews ? '...' : topProfile,
                label: 'Top',
                icon: CupertinoIcons.star_fill,
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
          color: AppColors.textTertiary.withValues(alpha: 0.6),
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
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
