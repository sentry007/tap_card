/// Connection Trends Widget
///
/// Displays analytics about connection growth patterns including:
/// - Most active day
/// - Average connections per week
/// - Connection velocity trend
library;

import 'package:flutter/material.dart';
import 'dart:ui';

import '../../theme/theme.dart';

class ConnectionTrends {
  final String mostActiveDay;
  final int mostActiveDayCount;
  final double avgConnectionsPerWeek;
  final int longestStreak;
  final String velocityTrend; // 'up', 'down', 'steady'

  ConnectionTrends({
    required this.mostActiveDay,
    required this.mostActiveDayCount,
    required this.avgConnectionsPerWeek,
    required this.longestStreak,
    required this.velocityTrend,
  });
}

class ConnectionTrendsWidget extends StatelessWidget {
  final ConnectionTrends trends;

  const ConnectionTrendsWidget({
    super.key,
    required this.trends,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connection Trends',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildTrendCard(
              icon: Icons.calendar_today,
              label: 'Most Active Day',
              value: '${trends.mostActiveDay} (${trends.mostActiveDayCount})',
              color: AppColors.success,
            ),
            _buildTrendCard(
              icon: Icons.timeline,
              label: 'Avg. per Week',
              value: trends.avgConnectionsPerWeek.toStringAsFixed(1),
              color: AppColors.info,
            ),
            _buildTrendCard(
              icon: Icons.local_fire_department,
              label: 'Longest Streak',
              value: '${trends.longestStreak} days',
              color: AppColors.secondaryAction,
            ),
            _buildTrendCard(
              icon: _getVelocityIcon(),
              label: 'Trend',
              value: _getVelocityText(),
              color: _getVelocityColor(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getVelocityIcon() {
    switch (trends.velocityTrend) {
      case 'up':
        return Icons.trending_up;
      case 'down':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  String _getVelocityText() {
    switch (trends.velocityTrend) {
      case 'up':
        return 'Growing';
      case 'down':
        return 'Declining';
      default:
        return 'Steady';
    }
  }

  Color _getVelocityColor() {
    switch (trends.velocityTrend) {
      case 'up':
        return AppColors.success;
      case 'down':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
