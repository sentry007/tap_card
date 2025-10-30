import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import '../../core/constants/routes.dart';

/// Activity Insights Widget
///
/// Displays a summary card of recent activity including:
/// - Cards sent in the last 7 days
/// - Cards received in the last 7 days
/// - New contacts in the last 24 hours
/// - Profile views (placeholder)
///
/// Tappable to navigate to the full insights screen.
class ActivityInsightsWidget extends StatelessWidget {
  const ActivityInsightsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryEntry>>(
      stream: HistoryService.historyStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return _ActivityInsightsCard(history: snapshot.data!);
      },
    );
  }
}

/// Internal widget that displays the insights card
class _ActivityInsightsCard extends StatelessWidget {
  final List<HistoryEntry> history;

  const _ActivityInsightsCard({required this.history});

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
    final newContacts = recentHistory
        .where((e) =>
            e.type == HistoryEntryType.received &&
            now.difference(e.timestamp).inHours < 24)
        .length;

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
            ? _buildActivityStats(sentCount, receivedCount, newContacts)
            : _buildEmptyState(),
      ),
    );
  }

  Widget _buildActivityStats(int sentCount, int receivedCount, int newContacts) {
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
                value: newContacts.toString(),
                label: 'New',
                icon: CupertinoIcons.sparkles,
                color: AppColors.info,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withOpacity(0.1),
            ),
            const Expanded(
              child: _InsightStat(
                value: '---',
                label: 'Views',
                icon: CupertinoIcons.eye_fill,
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
          'Start sharing with Atlas Linq to see insights!',
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
