/// Activity Chart Widget
///
/// Displays a 7-day activity chart with sent vs received breakdown
/// Fixed layout to prevent overflow issues
library;

import 'package:flutter/material.dart';
import 'dart:ui';

import '../../theme/theme.dart';

class DayActivity {
  int sent;
  int received;
  int tags;

  DayActivity({required this.sent, required this.received, this.tags = 0});
}

class ActivityChartWidget extends StatelessWidget {
  final Map<DateTime, DayActivity> chartData;

  const ActivityChartWidget({
    super.key,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    final sortedDays = chartData.keys.toList()..sort();
    final maxActivity = chartData.values
        .map((day) => day.sent + day.received + day.tags)
        .reduce((a, b) => a > b ? a : b);
    final maxHeight = maxActivity == 0 ? 1 : maxActivity;

    // Calculate totals for subtitle
    int totalSent = 0;
    int totalReceived = 0;
    int totalTags = 0;
    for (var activity in chartData.values) {
      totalSent += activity.sent;
      totalReceived += activity.received;
      totalTags += activity.tags;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Activity (Last 7 Days)',
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$totalSent sent · $totalReceived received · $totalTags tags',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.glassGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Received', AppColors.success),
                      const SizedBox(width: 16),
                      _buildLegendItem('Sent', AppColors.highlight),
                      const SizedBox(width: 16),
                      _buildLegendItem('Tags', AppColors.secondaryAction),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Chart
                  SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: sortedDays.asMap().entries.map((entry) {
                        final day = entry.value;
                        final activity = chartData[day]!;
                        return Expanded(
                          child: _buildDayBar(day, activity, maxHeight),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayBar(DateTime day, DayActivity activity, int maxHeight) {
    final total = activity.sent + activity.received + activity.tags;
    final sentHeight = maxHeight == 0 ? 0.0 : (activity.sent / maxHeight) * 100;
    final receivedHeight = maxHeight == 0 ? 0.0 : (activity.received / maxHeight) * 100;
    final tagsHeight = maxHeight == 0 ? 0.0 : (activity.tags / maxHeight) * 100;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Total count above bar
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '$total',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            )
          else
            const SizedBox(height: 14),
          // Stacked bars
          SizedBox(
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Received (green) on top
                if (receivedHeight > 0)
                  Container(
                    height: receivedHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success,
                          AppColors.success.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: sentHeight == 0 && tagsHeight == 0
                          ? BorderRadius.circular(6)
                          : const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                    ),
                  ),
                // Sent (orange) in middle
                if (sentHeight > 0)
                  Container(
                    height: sentHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.highlight,
                          AppColors.highlight.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: receivedHeight == 0 && tagsHeight == 0
                          ? BorderRadius.circular(6)
                          : null,
                    ),
                  ),
                // Tags (purple) on bottom
                if (tagsHeight > 0)
                  Container(
                    height: tagsHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondaryAction,
                          AppColors.secondaryAction.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: receivedHeight == 0 && sentHeight == 0
                          ? BorderRadius.circular(6)
                          : const BorderRadius.vertical(
                              bottom: Radius.circular(6),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Day label - using abbreviated format
          Text(
            _getDayLabel(day),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getDayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayDate = DateTime(day.year, day.month, day.day);

    if (dayDate == today) return 'Tod';
    if (dayDate == today.subtract(const Duration(days: 1))) return 'Yes';

    // Use single letter for days of week to save space
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return days[day.weekday % 7];
  }
}
