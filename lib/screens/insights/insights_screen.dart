/// Insights & Analytics Screen
///
/// Comprehensive dashboard showing user activity metrics:
/// - Overview stats (total shares, connections, monthly activity, favorite method)
/// - Activity chart (7-day sent vs received)
/// - Breakdown sections (share methods, top connections, milestones)
///
/// Uses real-time data from HistoryService with client-side analytics calculations
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:developer' as developer;

import '../../theme/theme.dart';
import '../../models/unified_models.dart';
import '../../services/history_service.dart';
import '../../widgets/history/method_chip.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  @override
  void initState() {
    super.initState();
    developer.log('📊 Insights screen initialized', name: 'Insights');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: StreamBuilder<List<HistoryEntry>>(
          stream: HistoryService.historyStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                ),
              );
            }

            final historyEntries = snapshot.data!;
            final analytics = _calculateAnalytics(historyEntries);

            return CustomScrollView(
              slivers: [
                // Glass AppBar with back button
                SliverAppBar(
                  expandedHeight: 0,
                  floating: true,
                  pinned: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.pop();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.back,
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppColors.secondaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.info.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.insights,
                                color: AppColors.textPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Insights & Analytics',
                                    style: AppTextStyles.h1.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your Atlas Linq activity overview',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Overview Stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildOverviewStats(analytics),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // Activity Chart Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildActivityChart(analytics),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // Share Methods Breakdown
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildShareMethodsBreakdown(analytics),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // Top Connections
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildTopConnections(analytics),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // Milestones
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildMilestones(analytics),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Calculate all analytics from history entries
  _Analytics _calculateAnalytics(List<HistoryEntry> entries) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Total counts
    final totalSent = entries.where((e) => e.type == HistoryEntryType.sent).length;
    final totalReceived = entries.where((e) => e.type == HistoryEntryType.received).length;
    // "Connections" = Total of sent + received entries
    // Note: In other parts of the app, "connections" specifically refers to people who shared with you (received only)
    // Here in analytics, we use it broadly to mean all interactions (both sent and received)
    final totalConnections = totalSent + totalReceived;

    // Monthly activity
    final monthlyEntries = entries.where((e) => e.timestamp.isAfter(thirtyDaysAgo)).toList();
    final monthlySent = monthlyEntries.where((e) => e.type == HistoryEntryType.sent).length;
    final monthlyReceived = monthlyEntries.where((e) => e.type == HistoryEntryType.received).length;
    final monthlyTotal = monthlySent + monthlyReceived;

    // Share method breakdown
    final methodCounts = <ShareMethod, int>{};
    for (final entry in entries) {
      if (entry.type == HistoryEntryType.sent) {
        methodCounts[entry.method] = (methodCounts[entry.method] ?? 0) + 1;
      }
    }

    // Favorite method
    ShareMethod? favoriteMethod;
    int maxCount = 0;
    methodCounts.forEach((method, count) {
      if (count > maxCount) {
        maxCount = count;
        favoriteMethod = method;
      }
    });

    // 7-day activity chart data
    final chartData = <DateTime, _DayActivity>{};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      chartData[day] = _DayActivity(sent: 0, received: 0);
    }

    for (final entry in entries) {
      if (entry.timestamp.isAfter(sevenDaysAgo)) {
        final entryDay = DateTime(
          entry.timestamp.year,
          entry.timestamp.month,
          entry.timestamp.day,
        );
        if (chartData.containsKey(entryDay)) {
          if (entry.type == HistoryEntryType.sent) {
            chartData[entryDay]!.sent++;
          } else if (entry.type == HistoryEntryType.received) {
            chartData[entryDay]!.received++;
          }
        }
      }
    }

    // Top connections (by frequency)
    final connectionCounts = <String, _ConnectionData>{};
    for (final entry in entries) {
      if (entry.type == HistoryEntryType.received && entry.senderProfile != null) {
        final name = entry.senderProfile!.name;
        if (connectionCounts.containsKey(name)) {
          connectionCounts[name]!.count++;
          if (entry.timestamp.isAfter(connectionCounts[name]!.lastInteraction)) {
            connectionCounts[name]!.lastInteraction = entry.timestamp;
          }
        } else {
          connectionCounts[name] = _ConnectionData(
            name: name,
            count: 1,
            lastInteraction: entry.timestamp,
            profile: entry.senderProfile!,
          );
        }
      }
    }

    final topConnections = connectionCounts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return _Analytics(
      totalSent: totalSent,
      totalReceived: totalReceived,
      totalConnections: totalConnections,
      monthlyTotal: monthlyTotal,
      favoriteMethod: favoriteMethod,
      methodCounts: methodCounts,
      chartData: chartData,
      topConnections: topConnections.take(5).toList(),
    );
  }

  /// Overview stats cards
  Widget _buildOverviewStats(_Analytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.send,
                label: 'Total Shares',
                value: '${analytics.totalSent}',
                color: AppColors.primaryAction,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.people,
                label: 'Connections',
                value: '${analytics.totalReceived}',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_month,
                label: 'This Month',
                value: '${analytics.monthlyTotal}',
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.star,
                label: 'Favorite',
                value: analytics.favoriteMethod?.label ?? 'N/A',
                color: AppColors.highlight,
                isSmallText: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isSmallText = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: isSmallText
                    ? AppTextStyles.h3.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      )
                    : AppTextStyles.h1.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Activity chart showing 7-day sent vs received
  Widget _buildActivityChart(_Analytics analytics) {
    final sortedDays = analytics.chartData.keys.toList()..sort();
    final maxActivity = analytics.chartData.values
        .map((day) => day.sent + day.received)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final chartHeight = maxActivity == 0 ? 1.0 : maxActivity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity (Last 7 Days)',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.bold,
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
                      _buildLegendItem('Sent', AppColors.primaryAction),
                      const SizedBox(width: 24),
                      _buildLegendItem('Received', AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Chart bars
                  SizedBox(
                    height: 160,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: sortedDays.map((day) {
                        final activity = analytics.chartData[day]!;
                        return _buildChartBar(day, activity, chartHeight);
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

  Widget _buildChartBar(DateTime day, _DayActivity activity, double maxHeight) {
    final total = activity.sent + activity.received;
    final sentHeight = maxHeight == 0 ? 0.0 : (activity.sent / maxHeight) * 140;
    final receivedHeight = maxHeight == 0 ? 0.0 : (activity.received / maxHeight) * 140;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bars
        SizedBox(
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (receivedHeight > 0)
                Container(
                  width: 32,
                  height: receivedHeight,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              if (sentHeight > 0)
                Container(
                  width: 32,
                  height: sentHeight,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAction,
                    borderRadius: receivedHeight == 0
                        ? BorderRadius.circular(4)
                        : const BorderRadius.vertical(
                            bottom: Radius.circular(4),
                          ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Day label
        Text(
          _getDayLabel(day),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
          ),
        ),
        if (total > 0)
          Text(
            '$total',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
      ],
    );
  }

  String _getDayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayDate = DateTime(day.year, day.month, day.day);

    if (dayDate == today) return 'Today';
    if (dayDate == today.subtract(const Duration(days: 1))) return 'Yest';

    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[day.weekday % 7];
  }

  /// Share methods breakdown
  Widget _buildShareMethodsBreakdown(_Analytics analytics) {
    if (analytics.methodCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedMethods = analytics.methodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalShares = analytics.totalSent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share Methods',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.bold,
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
                children: sortedMethods.map((entry) {
                  final percentage = totalShares == 0
                      ? 0.0
                      : (entry.value / totalShares * 100);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildMethodRow(
                      entry.key,
                      entry.value,
                      percentage,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodRow(ShareMethod method, int count, double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MethodChip(method: method, fontSize: 12, iconSize: 14),
            Text(
              '$count (${percentage.toStringAsFixed(0)}%)',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: AppColors.surfaceDark,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getMethodColor(method),
            ),
          ),
        ),
      ],
    );
  }

  Color _getMethodColor(ShareMethod method) {
    switch (method) {
      case ShareMethod.nfc:
        return AppColors.primaryAction;
      case ShareMethod.qr:
        return AppColors.success;
      case ShareMethod.web:
        return AppColors.info;
      case ShareMethod.tag:
        return AppColors.secondaryAction;
    }
  }

  /// Top connections list
  Widget _buildTopConnections(_Analytics analytics) {
    if (analytics.topConnections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Connections',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.bold,
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
                children: analytics.topConnections.asMap().entries.map((entry) {
                  final index = entry.key;
                  final connection = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < analytics.topConnections.length - 1 ? 16 : 0,
                    ),
                    child: _buildConnectionRow(connection, index + 1),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionRow(_ConnectionData connection, int rank) {
    final hasImage = connection.profile.profileImagePath != null &&
        connection.profile.profileImagePath!.isNotEmpty;

    return Row(
      children: [
        // Rank badge
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _getRankColor(rank).withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _getRankColor(rank),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: AppTextStyles.caption.copyWith(
                color: _getRankColor(rank),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Profile image or initials
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.secondaryAction.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.secondaryAction.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    connection.profile.profileImagePath!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        _getInitials(connection.name),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.secondaryAction,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    _getInitials(connection.name),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondaryAction,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        // Name and details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connection.name,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${connection.count} interaction${connection.count > 1 ? 's' : ''}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        // Count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${connection.count}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.highlight;
      case 2:
        return AppColors.textSecondary;
      case 3:
        return AppColors.primaryAction;
      default:
        return AppColors.info;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'
        .toUpperCase();
  }

  /// Milestones section
  Widget _buildMilestones(_Analytics analytics) {
    final milestones = <_Milestone>[];

    // Add milestones based on activity
    if (analytics.totalConnections >= 1) {
      milestones.add(_Milestone(
        icon: Icons.celebration,
        title: 'First Connection',
        description: 'You\'ve made your first Atlas Linq connection!',
        color: AppColors.success,
      ));
    }

    if (analytics.totalConnections >= 10) {
      milestones.add(_Milestone(
        icon: Icons.groups,
        title: '10 Connections',
        description: 'You\'ve connected with 10 people',
        color: AppColors.info,
      ));
    }

    if (analytics.totalConnections >= 50) {
      milestones.add(_Milestone(
        icon: Icons.star,
        title: 'Networking Pro',
        description: '50+ connections made!',
        color: AppColors.highlight,
      ));
    }

    if (analytics.totalSent >= 20) {
      milestones.add(_Milestone(
        icon: Icons.send,
        title: 'Share Master',
        description: 'Shared your card 20+ times',
        color: AppColors.primaryAction,
      ));
    }

    if (milestones.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Milestones',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: milestones.map((milestone) {
            return _buildMilestoneCard(milestone);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMilestoneCard(_Milestone milestone) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                milestone.color.withOpacity(0.15),
                milestone.color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: milestone.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                milestone.icon,
                color: milestone.color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    milestone.title,
                    style: AppTextStyles.caption.copyWith(
                      color: milestone.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    milestone.description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Data Models
// ============================================================================

class _Analytics {
  final int totalSent;
  final int totalReceived;
  final int totalConnections;
  final int monthlyTotal;
  final ShareMethod? favoriteMethod;
  final Map<ShareMethod, int> methodCounts;
  final Map<DateTime, _DayActivity> chartData;
  final List<_ConnectionData> topConnections;

  _Analytics({
    required this.totalSent,
    required this.totalReceived,
    required this.totalConnections,
    required this.monthlyTotal,
    required this.favoriteMethod,
    required this.methodCounts,
    required this.chartData,
    required this.topConnections,
  });
}

class _DayActivity {
  int sent;
  int received;

  _DayActivity({required this.sent, required this.received});
}

class _ConnectionData {
  final String name;
  int count;
  DateTime lastInteraction;
  final ProfileData profile;

  _ConnectionData({
    required this.name,
    required this.count,
    required this.lastInteraction,
    required this.profile,
  });
}

class _Milestone {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _Milestone({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
