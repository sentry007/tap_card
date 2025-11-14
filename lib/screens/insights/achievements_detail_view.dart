/// Achievements Detail View
///
/// Full-screen modal showing all 45 achievements organized by category.
/// Displays both unlocked (colored) and locked (greyed) achievements.
library;

import 'package:flutter/material.dart';
import 'dart:ui';

import '../../theme/theme.dart';

class AchievementsDetailView extends StatelessWidget {
  final List<Achievement> unlockedAchievements;
  final List<Achievement> allAchievements;

  const AchievementsDetailView({
    super.key,
    required this.unlockedAchievements,
    required this.allAchievements,
  });

  @override
  Widget build(BuildContext context) {
    // Organize achievements by category
    final sharingAchievements = allAchievements.where((a) => a.category == AchievementCategory.sharing).toList();
    final connectionAchievements = allAchievements.where((a) => a.category == AchievementCategory.connections).toList();
    final activityAchievements = allAchievements.where((a) => a.category == AchievementCategory.activity).toList();
    final specialAchievements = allAchievements.where((a) => a.category == AchievementCategory.special).toList();

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            _buildAppBar(context),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Progress Summary
                  _buildProgressSummary(),
                  const SizedBox(height: 32),

                  // Sharing Achievements
                  _buildCategorySection(
                    'Sharing Achievements',
                    sharingAchievements,
                    Icons.send_rounded,
                    AppColors.primaryAction,
                  ),
                  const SizedBox(height: 24),

                  // Connection Achievements
                  _buildCategorySection(
                    'Connection Achievements',
                    connectionAchievements,
                    Icons.people_rounded,
                    AppColors.success,
                  ),
                  const SizedBox(height: 24),

                  // Activity Achievements
                  _buildCategorySection(
                    'Activity Achievements',
                    activityAchievements,
                    Icons.trending_up_rounded,
                    AppColors.info,
                  ),
                  const SizedBox(height: 24),

                  // Special Achievements
                  _buildCategorySection(
                    'Special Achievements',
                    specialAchievements,
                    Icons.star_rounded,
                    AppColors.highlight,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.glassGradient,
            border: Border(
              bottom: BorderSide(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Text(
                'All Achievements',
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSummary() {
    final unlockedCount = unlockedAchievements.length;
    final totalCount = allAchievements.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.highlight.withValues(alpha: 0.2),
                AppColors.primaryAction.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.highlight.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Progress',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$unlockedCount / $totalCount',
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.highlight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.highlight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: AppColors.highlight,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: AppColors.surfaceDark,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.highlight),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toInt()}% Complete',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    List<Achievement> achievements,
    IconData icon,
    Color color,
  ) {
    final unlockedInCategory = achievements.where((a) =>
      unlockedAchievements.any((unlocked) => unlocked.title == a.title)
    ).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '$unlockedInCategory/${achievements.length}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: achievements.map((achievement) {
            final isUnlocked = unlockedAchievements.any((a) => a.title == achievement.title);
            return _buildAchievementCard(achievement, isUnlocked);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isUnlocked) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isUnlocked
                  ? [
                      achievement.color.withValues(alpha: 0.15),
                      achievement.color.withValues(alpha: 0.05),
                    ]
                  : [
                      AppColors.surfaceDark.withValues(alpha: 0.3),
                      AppColors.surfaceDark.withValues(alpha: 0.1),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnlocked
                  ? achievement.color.withValues(alpha: 0.3)
                  : AppColors.glassBorder.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    achievement.icon,
                    color: isUnlocked ? achievement.color : AppColors.textTertiary,
                    size: 40,
                  ),
                  if (!isUnlocked)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                achievement.title,
                style: AppTextStyles.body.copyWith(
                  color: isUnlocked ? achievement.color : AppColors.textTertiary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Description
              Text(
                achievement.description,
                style: AppTextStyles.caption.copyWith(
                  color: isUnlocked ? AppColors.textSecondary : AppColors.textTertiary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Achievement data model
class Achievement {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final AchievementCategory category;

  Achievement({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.category,
  });
}

enum AchievementCategory {
  sharing,
  connections,
  activity,
  special,
}
