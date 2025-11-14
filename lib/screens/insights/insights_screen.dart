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
import '../../services/profile_performance_service.dart';
import '../../core/services/profile_service.dart';
import '../../widgets/history/method_chip.dart';
import '../../widgets/common/glass_app_bar.dart';
import '../../widgets/common/app_info_button.dart';
import '../../widgets/insights/insight_stat_card.dart';
import '../../widgets/insights/connection_trends_widget.dart';
import '../../widgets/insights/activity_chart_widget.dart';
import 'achievements_detail_view.dart';

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
      body: StreamBuilder<List<HistoryEntry>>(
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

          return Stack(
            children: [
              // Main content with scroll
              CustomScrollView(
                slivers: [
                  // Top padding for app bar
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.top + 96,
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
                      child: ActivityChartWidget(
                        chartData: analytics.chartData.map(
                          (key, value) => MapEntry(
                            key,
                            DayActivity(sent: value.sent, received: value.received, tags: value.tags),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Profile Views Section (from Firestore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildProfileViewsSection(),
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

                  // Connection Trends
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildConnectionTrends(analytics),
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
              ),
              // Glass App Bar overlay
              GlassAppBar(
                leading: GlassIconButton(
                  icon: CupertinoIcons.back,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                  semanticsLabel: 'Back',
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Image.asset(
                        'assets/images/atlaslinq_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Insights',
                      style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                trailing: GlassIconButton(
                  icon: CupertinoIcons.settings,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/settings');
                  },
                  semanticsLabel: 'Settings',
                ),
              ),
            ],
          );
        },
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

    // Share method breakdown (received - how people share with you)
    final methodCounts = <ShareMethod, int>{};
    for (final entry in entries) {
      if (entry.type == HistoryEntryType.received) {
        methodCounts[entry.method] = (methodCounts[entry.method] ?? 0) + 1;
      }
    }

    // Top received method (how people share with you)
    final receivedMethodCounts = <ShareMethod, int>{};
    for (final entry in entries) {
      if (entry.type == HistoryEntryType.received) {
        receivedMethodCounts[entry.method] = (receivedMethodCounts[entry.method] ?? 0) + 1;
      }
    }

    ShareMethod? topReceivedMethod;
    int maxReceivedCount = 0;
    receivedMethodCounts.forEach((method, count) {
      if (count > maxReceivedCount) {
        maxReceivedCount = count;
        topReceivedMethod = method;
      }
    });

    // 7-day activity chart data
    final chartData = <DateTime, _DayActivity>{};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      chartData[day] = _DayActivity(sent: 0, received: 0, tags: 0);
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
          } else if (entry.type == HistoryEntryType.tag) {
            chartData[entryDay]!.tags++;
          }
        }
      }
    }

    // Recent connections (last 3 people who shared with you)
    final recentConnections = <_ConnectionData>[];
    final seenNames = <String>{};

    // Iterate through entries in reverse (most recent first)
    for (final entry in entries.reversed) {
      if (entry.type == HistoryEntryType.received &&
          entry.senderProfile != null &&
          !seenNames.contains(entry.senderProfile!.name)) {
        seenNames.add(entry.senderProfile!.name);
        recentConnections.add(_ConnectionData(
          name: entry.senderProfile!.name,
          count: 1, // Not tracking count anymore since you only receive once
          lastInteraction: entry.timestamp,
          profile: entry.senderProfile!,
        ));

        if (recentConnections.length >= 3) break;
      }
    }

    return _Analytics(
      totalSent: totalSent,
      totalReceived: totalReceived,
      totalConnections: totalConnections,
      monthlyTotal: monthlyTotal,
      topReceivedMethod: topReceivedMethod,
      methodCounts: methodCounts,
      chartData: chartData,
      recentConnections: recentConnections,
    );
  }

  /// Overview stats cards with enhanced metrics
  Widget _buildOverviewStats(_Analytics analytics) {
    // Calculate 7-day activity for comparison
    final last7DaysSent = analytics.chartData.values
        .fold<int>(0, (sum, day) => sum + day.sent);

    // Calculate connections this week
    final connectionsThisWeek = analytics.chartData.values
        .fold<int>(0, (sum, day) => sum + day.received);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overview',
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppInfoButton(
              title: 'Overview Stats',
              description: 'Your key metrics at a glance. Total Shares shows cards you\'ve sent, Connections shows cards received, This Month tracks monthly activity, Top Method shows your most used sharing method, and Profile Views shows total profile views across all your profiles.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InsightStatCard(
                icon: Icons.send,
                label: 'Total Shares',
                value: '${analytics.totalSent}',
                subtitle: 'Last 7 days: $last7DaysSent',
                color: AppColors.primaryAction,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InsightStatCard(
                icon: Icons.people,
                label: 'Connections',
                value: '${analytics.totalReceived}',
                subtitle: connectionsThisWeek > 0 ? '+$connectionsThisWeek this week' : 'No new this week',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InsightStatCard(
                icon: Icons.calendar_month,
                label: 'This Month',
                value: '${analytics.monthlyTotal}',
                subtitle: _getMonthComparison(analytics),
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InsightStatCard(
                icon: Icons.star,
                label: 'Top Method',
                value: analytics.topReceivedMethod?.label ?? 'N/A',
                subtitle: _getTopMethodCount(analytics),
                color: AppColors.highlight,
                isSmallText: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Profile Views Card
        _buildProfileViewsStatCard(),
      ],
    );
  }

  String _getMonthComparison(_Analytics analytics) {
    // Simple heuristic: compare to previous 30 days
    // For now, just show active status
    if (analytics.monthlyTotal == 0) return 'No activity';
    if (analytics.monthlyTotal < 5) return 'Getting started';
    if (analytics.monthlyTotal < 20) return 'Active user';
    return 'Power user!';
  }

  String _getTopMethodCount(_Analytics analytics) {
    if (analytics.topReceivedMethod == null) return 'None yet';
    final count = analytics.methodCounts[analytics.topReceivedMethod] ?? 0;
    return '($count uses)';
  }

  Widget _buildProfileViewsStatCard() {
    final profileService = ProfileService();
    final profiles = profileService.profiles;

    if (profiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<int>(
      future: ProfilePerformanceService.getTotalViewCount(profiles),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == 0) {
          return const SizedBox.shrink();
        }

        final totalViews = snapshot.data!;
        return InsightStatCard(
          icon: Icons.visibility,
          label: 'Profile Views',
          value: '$totalViews',
          subtitle: 'Across ${profiles.length} ${profiles.length == 1 ? "profile" : "profiles"}',
          color: AppColors.secondaryAction,
        );
      },
    );
  }

  /// Connection Trends - Calculate and display growth analytics
  Widget _buildConnectionTrends(_Analytics analytics) {
    if (analytics.totalReceived == 0) {
      return const SizedBox.shrink();
    }

    // Calculate trends
    final trends = _calculateConnectionTrends(analytics);

    return ConnectionTrendsWidget(trends: trends);
  }

  ConnectionTrends _calculateConnectionTrends(_Analytics analytics) {
    // Find most active day
    String mostActiveDay = 'None';
    int mostActiveDayCount = 0;

    analytics.chartData.forEach((date, activity) {
      if (activity.received > mostActiveDayCount) {
        mostActiveDayCount = activity.received;
        mostActiveDay = _getDayLabel(date);
      }
    });

    // Calculate average connections per week
    final weeksOfData = analytics.totalReceived > 0 ? 1 : 1; // Simplified
    final avgConnectionsPerWeek = analytics.totalReceived / weeksOfData;

    // Calculate longest streak
    int longestStreak = 0;
    int currentStreak = 0;
    final sortedDays = analytics.chartData.keys.toList()..sort();

    for (var day in sortedDays) {
      if (analytics.chartData[day]!.received > 0) {
        currentStreak++;
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
    }

    // Determine velocity trend
    final firstHalf = analytics.chartData.values.take(3).fold<int>(
      0, (sum, day) => sum + day.received
    );
    final secondHalf = analytics.chartData.values.skip(4).fold<int>(
      0, (sum, day) => sum + day.received
    );

    String velocityTrend = 'steady';
    if (secondHalf > firstHalf * 1.5) {
      velocityTrend = 'up';
    } else if (secondHalf < firstHalf * 0.5 && firstHalf > 0) {
      velocityTrend = 'down';
    }

    return ConnectionTrends(
      mostActiveDay: mostActiveDay,
      mostActiveDayCount: mostActiveDayCount,
      avgConnectionsPerWeek: avgConnectionsPerWeek,
      longestStreak: longestStreak,
      velocityTrend: velocityTrend,
    );
  }

  /// Activity chart showing 7-day sent vs received with vertical bars
  Widget _buildActivityChart(_Analytics analytics) {
    final sortedDays = analytics.chartData.keys.toList()..sort();
    final maxActivity = analytics.chartData.values
        .map((day) => day.sent + day.received)
        .reduce((a, b) => a > b ? a : b);
    final maxHeight = maxActivity == 0 ? 1 : maxActivity;

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
                  // Vertical Bar Chart
                  SizedBox(
                    height: 160,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: sortedDays.map((day) {
                        final activity = analytics.chartData[day]!;
                        return _buildDayBar(day, activity, maxHeight);
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

  Widget _buildDayBar(DateTime day, _DayActivity activity, int maxHeight) {
    final total = activity.sent + activity.received;
    final sentHeight = maxHeight == 0 ? 0.0 : (activity.sent / maxHeight) * 130;
    final receivedHeight = maxHeight == 0 ? 0.0 : (activity.received / maxHeight) * 130;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    fontSize: 11,
                  ),
                ),
              ),
            // Stacked bars
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 40),
              height: 130,
              alignment: Alignment.bottomCenter,
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
                        borderRadius: sentHeight == 0
                            ? BorderRadius.circular(8)
                            : const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  // Sent (blue) on bottom
                  if (sentHeight > 0)
                    Container(
                      height: sentHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryAction,
                            AppColors.primaryAction.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: receivedHeight == 0
                            ? BorderRadius.circular(8)
                            : const BorderRadius.vertical(
                                bottom: Radius.circular(8),
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryAction.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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

    if (dayDate == today) return 'Today';
    if (dayDate == today.subtract(const Duration(days: 1))) return 'Yest';

    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[day.weekday % 7];
  }

  /// Profile Performance Section - View counts per profile
  Widget _buildProfileViewsSection() {
    final profileService = ProfileService();
    final profiles = profileService.profiles;

    if (profiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<ProfileViewStats>>(
      future: ProfilePerformanceService.getAllProfileStats(profiles),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
            ),
          );
        }

        final stats = snapshot.data!;
        final totalViews = stats.fold<int>(0, (total, stat) => total + stat.viewCount);

        if (totalViews == 0) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profile Performance',
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$totalViews total views',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...stats.map((stat) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildProfilePerformanceCard(stat),
            )),
          ],
        );
      },
    );
  }

  Widget _buildProfilePerformanceCard(ProfileViewStats stat) {
    final profileIcon = stat.type == ProfileType.personal
        ? Icons.person
        : stat.type == ProfileType.professional
            ? Icons.business_center
            : Icons.settings;

    final profileColor = stat.type == ProfileType.personal
        ? AppColors.info
        : stat.type == ProfileType.professional
            ? AppColors.primaryAction
            : AppColors.secondaryAction;

    // Format last viewed
    String lastViewedText = 'Never viewed';
    if (stat.lastViewedAt != null) {
      final now = DateTime.now();
      final difference = now.difference(stat.lastViewedAt!);
      if (difference.inMinutes < 1) {
        lastViewedText = 'Just now';
      } else if (difference.inHours < 1) {
        lastViewedText = '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        lastViewedText = '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        lastViewedText = '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        lastViewedText = '${(difference.inDays / 7).floor()}w ago';
      } else {
        lastViewedText = '${(difference.inDays / 30).floor()}mo ago';
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                profileColor.withValues(alpha: 0.15),
                profileColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: profileColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              Row(
                children: [
                  Icon(
                    profileIcon,
                    color: profileColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    stat.type.label,
                    style: AppTextStyles.body.copyWith(
                      color: profileColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${stat.viewCount} views',
                    style: AppTextStyles.h3.copyWith(
                      color: profileColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: stat.percentageOfTotal / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            profileColor,
                            profileColor.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: profileColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lastViewedText,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    '${stat.percentageOfTotal.toStringAsFixed(0)}% of total',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
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

  /// Share methods breakdown
  Widget _buildShareMethodsBreakdown(_Analytics analytics) {
    if (analytics.methodCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedMethods = analytics.methodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalShares = analytics.totalReceived;

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
    final color = _getMethodColor(method);

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
        const SizedBox(height: 10),
        // Enhanced gradient progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
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

  /// Recent connections list (last 3 people who shared with you)
  Widget _buildTopConnections(_Analytics analytics) {
    if (analytics.recentConnections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Connections',
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
                children: analytics.recentConnections.asMap().entries.map((entry) {
                  final index = entry.key;
                  final connection = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < analytics.recentConnections.length - 1 ? 16 : 0,
                    ),
                    child: _buildRecentConnectionRow(connection),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentConnectionRow(_ConnectionData connection) {
    final hasImage = connection.profile.profileImagePath != null &&
        connection.profile.profileImagePath!.isNotEmpty;

    // Calculate time ago
    final now = DateTime.now();
    final difference = now.difference(connection.lastInteraction);
    String timeAgo;
    if (difference.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (difference.inHours < 1) {
      timeAgo = '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      timeAgo = '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      timeAgo = '${difference.inDays}d ago';
    } else {
      timeAgo = '${(difference.inDays / 7).floor()}w ago';
    }

    return Row(
      children: [
        // Profile image or initials
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
              width: 2,
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
                          color: AppColors.success,
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
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        // Name and time
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
                timeAgo,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        // New badge icon
        const Icon(
          Icons.person_add_alt_1,
          color: AppColors.success,
          size: 20,
        ),
      ],
    );
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

  /// Open achievements detail modal
  void _openAchievementsModal(BuildContext context, _Analytics analytics) {
    // Generate all unlocked achievements
    final unlockedAchievements = _generateUnlockedAchievements(analytics);

    // Generate all 45 achievements (locked + unlocked)
    final allAchievements = _generateAllAchievements();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AchievementsDetailView(
          unlockedAchievements: unlockedAchievements,
          allAchievements: allAchievements,
        ),
      ),
    );
  }

  /// Generate all unlocked achievements based on current analytics
  List<Achievement> _generateUnlockedAchievements(_Analytics analytics) {
    final achievements = <Achievement>[];

    // ========== SHARING ACHIEVEMENTS ==========
    if (analytics.totalSent >= 1) achievements.add(Achievement(icon: Icons.celebration, title: 'First Share', description: 'Shared your card for the first time', color: AppColors.primaryAction, category: AchievementCategory.sharing));
    if (analytics.totalSent >= 5) achievements.add(Achievement(icon: Icons.star_outline, title: 'Getting Started', description: '5 shares completed', color: AppColors.primaryAction, category: AchievementCategory.sharing));
    if (analytics.totalSent >= 10) achievements.add(Achievement(icon: Icons.send, title: 'Share Rookie', description: '10 shares milestone', color: AppColors.primaryAction, category: AchievementCategory.sharing));
    if (analytics.totalSent >= 25) achievements.add(Achievement(icon: Icons.rocket_launch, title: 'Rising Star', description: '25 shares achieved', color: AppColors.primaryAction, category: AchievementCategory.sharing));
    if (analytics.totalSent >= 50) achievements.add(Achievement(icon: Icons.star, title: 'Share Master', description: '50+ shares completed', color: AppColors.primaryAction, category: AchievementCategory.sharing));
    if (analytics.totalSent >= 100) achievements.add(Achievement(icon: Icons.workspace_premium, title: 'Century Club', description: '100 shares milestone!', color: AppColors.highlight, category: AchievementCategory.sharing));
    if (analytics.totalSent >= 250) achievements.add(Achievement(icon: Icons.emoji_events, title: 'Share Legend', description: '250+ shares completed', color: AppColors.highlight, category: AchievementCategory.sharing));
    if (analytics.totalSent >= 500) achievements.add(Achievement(icon: Icons.military_tech, title: 'Share Champion', description: '500 shares achieved!', color: AppColors.highlight, category: AchievementCategory.sharing));
    if (analytics.totalSent >= 1000) achievements.add(Achievement(icon: Icons.diamond, title: 'Diamond Sharer', description: '1000+ shares!', color: AppColors.highlight, category: AchievementCategory.sharing));

    // Share methods diversity
    if (analytics.methodCounts.keys.length >= 2) achievements.add(Achievement(icon: Icons.explore, title: 'Explorer', description: 'Used 2 different share methods', color: AppColors.info, category: AchievementCategory.sharing));
    if (analytics.methodCounts.keys.length >= 3) achievements.add(Achievement(icon: Icons.diversity_3, title: 'Versatile', description: 'Used 3 different methods', color: AppColors.info, category: AchievementCategory.sharing));
    if (analytics.methodCounts.keys.length >= 4) achievements.add(Achievement(icon: Icons.apps, title: 'Omnichannel', description: 'Mastered all share methods', color: AppColors.info, category: AchievementCategory.sharing));

    // NFC specific
    final nfcCount = analytics.methodCounts[ShareMethod.nfc] ?? 0;
    if (nfcCount >= 10) achievements.add(Achievement(icon: Icons.nfc, title: 'NFC Novice', description: '10 NFC shares', color: AppColors.primaryAction, category: AchievementCategory.sharing));
    if (nfcCount >= 50) achievements.add(Achievement(icon: Icons.contactless, title: 'NFC Master', description: '50 NFC shares', color: AppColors.primaryAction, category: AchievementCategory.sharing));
    if (nfcCount >= 100) achievements.add(Achievement(icon: Icons.tap_and_play, title: 'NFC Legend', description: '100+ NFC shares!', color: AppColors.highlight, category: AchievementCategory.sharing));

    // ========== CONNECTION ACHIEVEMENTS ==========
    if (analytics.totalReceived >= 1) achievements.add(Achievement(icon: Icons.person_add, title: 'First Connection', description: 'Received your first card', color: AppColors.success, category: AchievementCategory.connections));
    if (analytics.totalReceived >= 5) achievements.add(Achievement(icon: Icons.people_outline, title: 'Social Starter', description: '5 connections made', color: AppColors.success, category: AchievementCategory.connections));
    if (analytics.totalReceived >= 10) achievements.add(Achievement(icon: Icons.groups_2, title: 'Networker', description: '10 connections milestone', color: AppColors.success, category: AchievementCategory.connections));
    if (analytics.totalReceived >= 25) achievements.add(Achievement(icon: Icons.diversity_2, title: 'Social Butterfly', description: '25 connections reached', color: AppColors.success, category: AchievementCategory.connections));
    if (analytics.totalReceived >= 50) achievements.add(Achievement(icon: Icons.groups, title: 'Networking Pro', description: '50+ connections!', color: AppColors.success, category: AchievementCategory.connections));
    if (analytics.totalReceived >= 100) achievements.add(Achievement(icon: Icons.group_add, title: 'Connection Champion', description: '100 connections made!', color: AppColors.highlight, category: AchievementCategory.connections));
    if (analytics.totalReceived >= 250) achievements.add(Achievement(icon: Icons.public, title: 'Connector Elite', description: '250+ connections!', color: AppColors.highlight, category: AchievementCategory.connections));
    if (analytics.totalReceived >= 500) achievements.add(Achievement(icon: Icons.hub, title: 'Network Hub', description: '500 connections achieved!', color: AppColors.highlight, category: AchievementCategory.connections));
    if (analytics.totalReceived >= 1000) achievements.add(Achievement(icon: Icons.language, title: 'Global Connector', description: '1000+ connections!', color: AppColors.highlight, category: AchievementCategory.connections));

    // Total interactions
    if (analytics.totalConnections >= 50) achievements.add(Achievement(icon: Icons.trending_up, title: 'Active User', description: '50 total interactions', color: AppColors.info, category: AchievementCategory.connections));
    if (analytics.totalConnections >= 150) achievements.add(Achievement(icon: Icons.auto_graph, title: 'Power User', description: '150+ total interactions', color: AppColors.info, category: AchievementCategory.connections));
    if (analytics.totalConnections >= 500) achievements.add(Achievement(icon: Icons.show_chart, title: 'Super User', description: '500+ interactions!', color: AppColors.highlight, category: AchievementCategory.connections));

    // ========== ACTIVITY ACHIEVEMENTS ==========
    if (analytics.monthlyTotal >= 10) achievements.add(Achievement(icon: Icons.calendar_month, title: 'Monthly Active', description: '10+ interactions this month', color: AppColors.info, category: AchievementCategory.activity));
    if (analytics.monthlyTotal >= 30) achievements.add(Achievement(icon: Icons.event_available, title: 'Monthly Champion', description: '30+ this month!', color: AppColors.info, category: AchievementCategory.activity));
    if (analytics.monthlyTotal >= 50) achievements.add(Achievement(icon: Icons.date_range, title: 'Monthly Legend', description: '50+ interactions this month!', color: AppColors.highlight, category: AchievementCategory.activity));

    // Weekly streaks
    final activeDaysThisWeek = analytics.chartData.values.where((day) => (day.sent + day.received) > 0).length;
    if (activeDaysThisWeek >= 3) achievements.add(Achievement(icon: Icons.local_fire_department, title: 'Consistent', description: '3+ active days this week', color: AppColors.secondaryAction, category: AchievementCategory.activity));
    if (activeDaysThisWeek >= 5) achievements.add(Achievement(icon: Icons.whatshot, title: 'On Fire', description: '5+ active days this week', color: AppColors.secondaryAction, category: AchievementCategory.activity));
    if (activeDaysThisWeek >= 7) achievements.add(Achievement(icon: Icons.bolt, title: 'Perfect Week', description: 'Active all 7 days!', color: AppColors.highlight, category: AchievementCategory.activity));

    // Daily achievements
    final maxDailyActivity = analytics.chartData.values.map((d) => d.sent + d.received).reduce((a, b) => a > b ? a : b);
    if (maxDailyActivity >= 5) achievements.add(Achievement(icon: Icons.today, title: 'Busy Day', description: '5+ interactions in one day', color: AppColors.info, category: AchievementCategory.activity));
    if (maxDailyActivity >= 10) achievements.add(Achievement(icon: Icons.schedule, title: 'Super Day', description: '10+ interactions in a day!', color: AppColors.info, category: AchievementCategory.activity));
    if (maxDailyActivity >= 20) achievements.add(Achievement(icon: Icons.flash_on, title: 'Power Day', description: '20+ in one day!', color: AppColors.highlight, category: AchievementCategory.activity));
    if (maxDailyActivity >= 50) achievements.add(Achievement(icon: Icons.speed, title: 'Mega Day', description: '50+ in one day!', color: AppColors.highlight, category: AchievementCategory.activity));

    // ========== SPECIAL ACHIEVEMENTS ==========
    final shareReceiveRatio = analytics.totalSent > 0 ? analytics.totalReceived / analytics.totalSent : 0;
    if (shareReceiveRatio >= 0.8 && shareReceiveRatio <= 1.2 && analytics.totalConnections >= 20) {
      achievements.add(Achievement(icon: Icons.balance, title: 'Balanced Networker', description: 'Equal give and take', color: AppColors.success, category: AchievementCategory.special));
    }

    if (analytics.methodCounts.isNotEmpty) {
      final maxMethodCount = analytics.methodCounts.values.reduce((a, b) => a > b ? a : b);
      if (maxMethodCount >= 50) achievements.add(Achievement(icon: Icons.settings, title: 'Method Master', description: '50+ with one method', color: AppColors.primaryAction, category: AchievementCategory.special));
    }

    if (analytics.totalConnections >= 10) achievements.add(Achievement(icon: Icons.flag, title: 'AtlasLinq Advocate', description: 'Active platform user', color: AppColors.highlight, category: AchievementCategory.special));
    achievements.add(Achievement(icon: Icons.account_circle, title: 'Profile Pro', description: 'Completed your profile', color: AppColors.info, category: AchievementCategory.special));
    if (analytics.recentConnections.length >= 3) achievements.add(Achievement(icon: Icons.forum, title: 'Community Member', description: 'Connected with multiple people', color: AppColors.success, category: AchievementCategory.special));

    return achievements;
  }

  /// Generate all 45 achievements (complete list)
  List<Achievement> _generateAllAchievements() {
    return [
      // SHARING (15)
      Achievement(icon: Icons.celebration, title: 'First Share', description: 'Shared your card for the first time', color: AppColors.primaryAction, category: AchievementCategory.sharing),
      Achievement(icon: Icons.star_outline, title: 'Getting Started', description: '5 shares completed', color: AppColors.primaryAction, category: AchievementCategory.sharing),
      Achievement(icon: Icons.send, title: 'Share Rookie', description: '10 shares milestone', color: AppColors.primaryAction, category: AchievementCategory.sharing),
      Achievement(icon: Icons.rocket_launch, title: 'Rising Star', description: '25 shares achieved', color: AppColors.primaryAction, category: AchievementCategory.sharing),
      Achievement(icon: Icons.star, title: 'Share Master', description: '50+ shares completed', color: AppColors.primaryAction, category: AchievementCategory.sharing),
      Achievement(icon: Icons.workspace_premium, title: 'Century Club', description: '100 shares milestone!', color: AppColors.highlight, category: AchievementCategory.sharing),
      Achievement(icon: Icons.emoji_events, title: 'Share Legend', description: '250+ shares completed', color: AppColors.highlight, category: AchievementCategory.sharing),
      Achievement(icon: Icons.military_tech, title: 'Share Champion', description: '500 shares achieved!', color: AppColors.highlight, category: AchievementCategory.sharing),
      Achievement(icon: Icons.diamond, title: 'Diamond Sharer', description: '1000+ shares!', color: AppColors.highlight, category: AchievementCategory.sharing),
      Achievement(icon: Icons.explore, title: 'Explorer', description: 'Used 2 different share methods', color: AppColors.info, category: AchievementCategory.sharing),
      Achievement(icon: Icons.diversity_3, title: 'Versatile', description: 'Used 3 different methods', color: AppColors.info, category: AchievementCategory.sharing),
      Achievement(icon: Icons.apps, title: 'Omnichannel', description: 'Mastered all share methods', color: AppColors.info, category: AchievementCategory.sharing),
      Achievement(icon: Icons.nfc, title: 'NFC Novice', description: '10 NFC shares', color: AppColors.primaryAction, category: AchievementCategory.sharing),
      Achievement(icon: Icons.contactless, title: 'NFC Master', description: '50 NFC shares', color: AppColors.primaryAction, category: AchievementCategory.sharing),
      Achievement(icon: Icons.tap_and_play, title: 'NFC Legend', description: '100+ NFC shares!', color: AppColors.highlight, category: AchievementCategory.sharing),

      // CONNECTIONS (15)
      Achievement(icon: Icons.person_add, title: 'First Connection', description: 'Received your first card', color: AppColors.success, category: AchievementCategory.connections),
      Achievement(icon: Icons.people_outline, title: 'Social Starter', description: '5 connections made', color: AppColors.success, category: AchievementCategory.connections),
      Achievement(icon: Icons.groups_2, title: 'Networker', description: '10 connections milestone', color: AppColors.success, category: AchievementCategory.connections),
      Achievement(icon: Icons.diversity_2, title: 'Social Butterfly', description: '25 connections reached', color: AppColors.success, category: AchievementCategory.connections),
      Achievement(icon: Icons.groups, title: 'Networking Pro', description: '50+ connections!', color: AppColors.success, category: AchievementCategory.connections),
      Achievement(icon: Icons.group_add, title: 'Connection Champion', description: '100 connections made!', color: AppColors.highlight, category: AchievementCategory.connections),
      Achievement(icon: Icons.public, title: 'Connector Elite', description: '250+ connections!', color: AppColors.highlight, category: AchievementCategory.connections),
      Achievement(icon: Icons.hub, title: 'Network Hub', description: '500 connections achieved!', color: AppColors.highlight, category: AchievementCategory.connections),
      Achievement(icon: Icons.language, title: 'Global Connector', description: '1000+ connections!', color: AppColors.highlight, category: AchievementCategory.connections),
      Achievement(icon: Icons.trending_up, title: 'Active User', description: '50 total interactions', color: AppColors.info, category: AchievementCategory.connections),
      Achievement(icon: Icons.auto_graph, title: 'Power User', description: '150+ total interactions', color: AppColors.info, category: AchievementCategory.connections),
      Achievement(icon: Icons.show_chart, title: 'Super User', description: '500+ interactions!', color: AppColors.highlight, category: AchievementCategory.connections),
      Achievement(icon: Icons.people_alt, title: 'Team Player', description: 'Share with 10+ people', color: AppColors.success, category: AchievementCategory.connections),
      Achievement(icon: Icons.groups_3, title: 'Network Builder', description: 'Share with 50+ people', color: AppColors.success, category: AchievementCategory.connections),
      Achievement(icon: Icons.public_rounded, title: 'Social Maven', description: 'Share with 100+ people', color: AppColors.highlight, category: AchievementCategory.connections),

      // ACTIVITY (10)
      Achievement(icon: Icons.calendar_month, title: 'Monthly Active', description: '10+ interactions this month', color: AppColors.info, category: AchievementCategory.activity),
      Achievement(icon: Icons.event_available, title: 'Monthly Champion', description: '30+ this month!', color: AppColors.info, category: AchievementCategory.activity),
      Achievement(icon: Icons.date_range, title: 'Monthly Legend', description: '50+ interactions this month!', color: AppColors.highlight, category: AchievementCategory.activity),
      Achievement(icon: Icons.local_fire_department, title: 'Consistent', description: '3+ active days this week', color: AppColors.secondaryAction, category: AchievementCategory.activity),
      Achievement(icon: Icons.whatshot, title: 'On Fire', description: '5+ active days this week', color: AppColors.secondaryAction, category: AchievementCategory.activity),
      Achievement(icon: Icons.bolt, title: 'Perfect Week', description: 'Active all 7 days!', color: AppColors.highlight, category: AchievementCategory.activity),
      Achievement(icon: Icons.today, title: 'Busy Day', description: '5+ interactions in one day', color: AppColors.info, category: AchievementCategory.activity),
      Achievement(icon: Icons.schedule, title: 'Super Day', description: '10+ interactions in a day!', color: AppColors.info, category: AchievementCategory.activity),
      Achievement(icon: Icons.flash_on, title: 'Power Day', description: '20+ in one day!', color: AppColors.highlight, category: AchievementCategory.activity),
      Achievement(icon: Icons.speed, title: 'Mega Day', description: '50+ in one day!', color: AppColors.highlight, category: AchievementCategory.activity),

      // SPECIAL (5)
      Achievement(icon: Icons.balance, title: 'Balanced Networker', description: 'Equal give and take', color: AppColors.success, category: AchievementCategory.special),
      Achievement(icon: Icons.settings, title: 'Method Master', description: '50+ with one method', color: AppColors.primaryAction, category: AchievementCategory.special),
      Achievement(icon: Icons.flag, title: 'AtlasLinq Advocate', description: 'Active platform user', color: AppColors.highlight, category: AchievementCategory.special),
      Achievement(icon: Icons.account_circle, title: 'Profile Pro', description: 'Completed your profile', color: AppColors.info, category: AchievementCategory.special),
      Achievement(icon: Icons.forum, title: 'Community Member', description: 'Connected with multiple people', color: AppColors.success, category: AchievementCategory.special),
    ];
  }

  /// Comprehensive achievements system with 45 achievements
  Widget _buildMilestones(_Analytics analytics) {
    final achievements = <_Achievement>[];

    // ========== SHARING ACHIEVEMENTS (15) ==========
    // First shares
    if (analytics.totalSent >= 1) achievements.add(_Achievement(icon: Icons.celebration, title: 'First Share', description: 'Shared your card for the first time', color: AppColors.primaryAction));
    if (analytics.totalSent >= 5) achievements.add(_Achievement(icon: Icons.star_outline, title: 'Getting Started', description: '5 shares completed', color: AppColors.primaryAction));
    if (analytics.totalSent >= 10) achievements.add(_Achievement(icon: Icons.send, title: 'Share Rookie', description: '10 shares milestone', color: AppColors.primaryAction));
    if (analytics.totalSent >= 25) achievements.add(_Achievement(icon: Icons.rocket_launch, title: 'Rising Star', description: '25 shares achieved', color: AppColors.primaryAction));
    if (analytics.totalSent >= 50) achievements.add(_Achievement(icon: Icons.star, title: 'Share Master', description: '50+ shares completed', color: AppColors.primaryAction));
    if (analytics.totalSent >= 100) achievements.add(_Achievement(icon: Icons.workspace_premium, title: 'Century Club', description: '100 shares milestone!', color: AppColors.highlight));
    if (analytics.totalSent >= 250) achievements.add(_Achievement(icon: Icons.emoji_events, title: 'Share Legend', description: '250+ shares completed', color: AppColors.highlight));
    if (analytics.totalSent >= 500) achievements.add(_Achievement(icon: Icons.military_tech, title: 'Share Champion', description: '500 shares achieved!', color: AppColors.highlight));
    if (analytics.totalSent >= 1000) achievements.add(_Achievement(icon: Icons.diamond, title: 'Diamond Sharer', description: '1000+ shares!', color: AppColors.highlight));

    // Share methods diversity
    if (analytics.methodCounts.keys.length >= 2) achievements.add(_Achievement(icon: Icons.explore, title: 'Explorer', description: 'Used 2 different share methods', color: AppColors.info));
    if (analytics.methodCounts.keys.length >= 3) achievements.add(_Achievement(icon: Icons.diversity_3, title: 'Versatile', description: 'Used 3 different methods', color: AppColors.info));
    if (analytics.methodCounts.keys.length >= 4) achievements.add(_Achievement(icon: Icons.apps, title: 'Omnichannel', description: 'Mastered all share methods', color: AppColors.info));

    // NFC specific
    final nfcCount = analytics.methodCounts[ShareMethod.nfc] ?? 0;
    if (nfcCount >= 10) achievements.add(_Achievement(icon: Icons.nfc, title: 'NFC Novice', description: '10 NFC shares', color: AppColors.primaryAction));
    if (nfcCount >= 50) achievements.add(_Achievement(icon: Icons.contactless, title: 'NFC Master', description: '50 NFC shares', color: AppColors.primaryAction));
    if (nfcCount >= 100) achievements.add(_Achievement(icon: Icons.tap_and_play, title: 'NFC Legend', description: '100+ NFC shares!', color: AppColors.highlight));

    // ========== CONNECTION ACHIEVEMENTS (15) ==========
    // Receiving connections
    if (analytics.totalReceived >= 1) achievements.add(_Achievement(icon: Icons.person_add, title: 'First Connection', description: 'Received your first card', color: AppColors.success));
    if (analytics.totalReceived >= 5) achievements.add(_Achievement(icon: Icons.people_outline, title: 'Social Starter', description: '5 connections made', color: AppColors.success));
    if (analytics.totalReceived >= 10) achievements.add(_Achievement(icon: Icons.groups_2, title: 'Networker', description: '10 connections milestone', color: AppColors.success));
    if (analytics.totalReceived >= 25) achievements.add(_Achievement(icon: Icons.diversity_2, title: 'Social Butterfly', description: '25 connections reached', color: AppColors.success));
    if (analytics.totalReceived >= 50) achievements.add(_Achievement(icon: Icons.groups, title: 'Networking Pro', description: '50+ connections!', color: AppColors.success));
    if (analytics.totalReceived >= 100) achievements.add(_Achievement(icon: Icons.group_add, title: 'Connection Champion', description: '100 connections made!', color: AppColors.highlight));
    if (analytics.totalReceived >= 250) achievements.add(_Achievement(icon: Icons.public, title: 'Connector Elite', description: '250+ connections!', color: AppColors.highlight));
    if (analytics.totalReceived >= 500) achievements.add(_Achievement(icon: Icons.hub, title: 'Network Hub', description: '500 connections achieved!', color: AppColors.highlight));
    if (analytics.totalReceived >= 1000) achievements.add(_Achievement(icon: Icons.language, title: 'Global Connector', description: '1000+ connections!', color: AppColors.highlight));

    // Recent connections (removed multiple interaction achievements since you only receive once)

    // Total interactions
    if (analytics.totalConnections >= 50) achievements.add(_Achievement(icon: Icons.trending_up, title: 'Active User', description: '50 total interactions', color: AppColors.info));
    if (analytics.totalConnections >= 150) achievements.add(_Achievement(icon: Icons.auto_graph, title: 'Power User', description: '150+ total interactions', color: AppColors.info));
    if (analytics.totalConnections >= 500) achievements.add(_Achievement(icon: Icons.show_chart, title: 'Super User', description: '500+ interactions!', color: AppColors.highlight));

    // ========== ACTIVITY ACHIEVEMENTS (10) ==========
    // Monthly activity
    if (analytics.monthlyTotal >= 10) achievements.add(_Achievement(icon: Icons.calendar_month, title: 'Monthly Active', description: '10+ interactions this month', color: AppColors.info));
    if (analytics.monthlyTotal >= 30) achievements.add(_Achievement(icon: Icons.event_available, title: 'Monthly Champion', description: '30+ this month!', color: AppColors.info));
    if (analytics.monthlyTotal >= 50) achievements.add(_Achievement(icon: Icons.date_range, title: 'Monthly Legend', description: '50+ interactions this month!', color: AppColors.highlight));

    // Weekly streaks (7-day activity)
    final activeDaysThisWeek = analytics.chartData.values.where((day) => (day.sent + day.received) > 0).length;
    if (activeDaysThisWeek >= 3) achievements.add(_Achievement(icon: Icons.local_fire_department, title: 'Consistent', description: '3+ active days this week', color: AppColors.secondaryAction));
    if (activeDaysThisWeek >= 5) achievements.add(_Achievement(icon: Icons.whatshot, title: 'On Fire', description: '5+ active days this week', color: AppColors.secondaryAction));
    if (activeDaysThisWeek >= 7) achievements.add(_Achievement(icon: Icons.bolt, title: 'Perfect Week', description: 'Active all 7 days!', color: AppColors.highlight));

    // Daily achievements
    final maxDailyActivity = analytics.chartData.values.map((d) => d.sent + d.received).reduce((a, b) => a > b ? a : b);
    if (maxDailyActivity >= 5) achievements.add(_Achievement(icon: Icons.today, title: 'Busy Day', description: '5+ interactions in one day', color: AppColors.info));
    if (maxDailyActivity >= 10) achievements.add(_Achievement(icon: Icons.schedule, title: 'Super Day', description: '10+ interactions in a day!', color: AppColors.info));
    if (maxDailyActivity >= 20) achievements.add(_Achievement(icon: Icons.flash_on, title: 'Power Day', description: '20+ in one day!', color: AppColors.highlight));
    if (maxDailyActivity >= 50) achievements.add(_Achievement(icon: Icons.speed, title: 'Mega Day', description: '50+ in one day!', color: AppColors.highlight));

    // ========== SPECIAL ACHIEVEMENTS (5) ==========
    // Balanced user
    final shareReceiveRatio = analytics.totalSent > 0 ? analytics.totalReceived / analytics.totalSent : 0;
    if (shareReceiveRatio >= 0.8 && shareReceiveRatio <= 1.2 && analytics.totalConnections >= 20) {
      achievements.add(_Achievement(icon: Icons.balance, title: 'Balanced Networker', description: 'Equal give and take', color: AppColors.success));
    }

    // Method master
    if (analytics.methodCounts.isNotEmpty) {
      final maxMethodCount = analytics.methodCounts.values.reduce((a, b) => a > b ? a : b);
      if (maxMethodCount >= 50) achievements.add(_Achievement(icon: Icons.settings, title: 'Method Master', description: '50+ with one method', color: AppColors.primaryAction));
    }

    // Early adopter (placeholder - would need registration date)
    if (analytics.totalConnections >= 10) achievements.add(_Achievement(icon: Icons.flag, title: 'AtlasLinq Advocate', description: 'Active platform user', color: AppColors.highlight));

    // Profile completeness (placeholder)
    achievements.add(_Achievement(icon: Icons.account_circle, title: 'Profile Pro', description: 'Completed your profile', color: AppColors.info));

    // Community member
    if (analytics.recentConnections.length >= 3) achievements.add(_Achievement(icon: Icons.forum, title: 'Community Member', description: 'Connected with multiple people', color: AppColors.success));

    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Achievements',
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _openAchievementsModal(context, analytics);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.highlight.withValues(alpha: 0.2),
                      AppColors.primaryAction.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.highlight.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${achievements.length}/45',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.highlight,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.highlight,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: achievements.map((achievement) {
            return _buildAchievementCard(achievement);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(_Achievement achievement) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                achievement.color.withValues(alpha: 0.15),
                achievement.color.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: achievement.color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                achievement.icon,
                color: achievement.color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    achievement.title,
                    style: AppTextStyles.caption.copyWith(
                      color: achievement.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    achievement.description,
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
  final ShareMethod? topReceivedMethod;
  final Map<ShareMethod, int> methodCounts;
  final Map<DateTime, _DayActivity> chartData;
  final List<_ConnectionData> recentConnections;

  _Analytics({
    required this.totalSent,
    required this.totalReceived,
    required this.totalConnections,
    required this.monthlyTotal,
    required this.topReceivedMethod,
    required this.methodCounts,
    required this.chartData,
    required this.recentConnections,
  });
}

class _DayActivity {
  int sent;
  int received;
  int tags;

  _DayActivity({required this.sent, required this.received, this.tags = 0});
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

class _Achievement {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _Achievement({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
