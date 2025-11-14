/// Achievements Detail View
///
/// Full-screen modal showing all 45 achievements organized by category.
/// Displays both unlocked (colored) and locked (greyed) achievements.
library;

import 'package:flutter/material.dart';
import 'dart:ui';

import '../../theme/theme.dart';

class AchievementsDetailView extends StatefulWidget {
  final List<Achievement> unlockedAchievements;
  final List<Achievement> allAchievements;

  const AchievementsDetailView({
    super.key,
    required this.unlockedAchievements,
    required this.allAchievements,
  });

  @override
  State<AchievementsDetailView> createState() => _AchievementsDetailViewState();
}

class _AchievementsDetailViewState extends State<AchievementsDetailView> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Sharing', 'Connect', 'Activity', 'Special'];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Organize achievements by category
    final sharingAchievements = widget.allAchievements.where((a) => a.category == AchievementCategory.sharing).toList();
    final connectionAchievements = widget.allAchievements.where((a) => a.category == AchievementCategory.connections).toList();
    final activityAchievements = widget.allAchievements.where((a) => a.category == AchievementCategory.activity).toList();
    final specialAchievements = widget.allAchievements.where((a) => a.category == AchievementCategory.special).toList();

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            _buildAppBar(context),

            // Progress Summary
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildProgressSummary(),
            ),

            // Filter Chips
            _buildFilterChips(),

            // Filtered Grid View
            Expanded(
              child: _buildGridView(_getFilteredAchievements(
                sharingAchievements,
                connectionAchievements,
                activityAchievements,
                specialAchievements,
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<Achievement> achievements) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        final isUnlocked = widget.unlockedAchievements.any((a) => a.title == achievement.title);
        return _buildAchievementCard(achievement, isUnlocked);
      },
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilterIndex == index;
          final filterColors = _getFilterColors(filter);

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() => _selectedFilterIndex = index);
                },
                borderRadius: BorderRadius.circular(18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? filterColors['background']!.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? filterColors['border']!
                              : Colors.white.withValues(alpha: 0.2),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: filterColors['shadow']!
                                      .withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        filter,
                        style: AppTextStyles.caption.copyWith(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, Color> _getFilterColors(String filter) {
    switch (filter) {
      case 'Sharing':
        return {
          'background': AppColors.primaryAction,
          'border': AppColors.primaryAction.withValues(alpha: 0.5),
          'shadow': AppColors.primaryAction,
        };
      case 'Connect':
        return {
          'background': AppColors.success,
          'border': AppColors.success.withValues(alpha: 0.5),
          'shadow': AppColors.success,
        };
      case 'Activity':
        return {
          'background': AppColors.highlight,
          'border': AppColors.highlight.withValues(alpha: 0.5),
          'shadow': AppColors.highlight,
        };
      case 'Special':
        return {
          'background': AppColors.secondaryAction,
          'border': AppColors.secondaryAction.withValues(alpha: 0.5),
          'shadow': AppColors.secondaryAction,
        };
      default:
        // 'All' filter
        return {
          'background': AppColors.textPrimary,
          'border': AppColors.textPrimary.withValues(alpha: 0.5),
          'shadow': AppColors.textPrimary,
        };
    }
  }

  List<Achievement> _getFilteredAchievements(
    List<Achievement> sharingAchievements,
    List<Achievement> connectionAchievements,
    List<Achievement> activityAchievements,
    List<Achievement> specialAchievements,
  ) {
    switch (_selectedFilterIndex) {
      case 1: // Sharing
        return sharingAchievements;
      case 2: // Connect
        return connectionAchievements;
      case 3: // Activity
        return activityAchievements;
      case 4: // Special
        return specialAchievements;
      default: // All
        return widget.allAchievements;
    }
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
    final unlockedCount = widget.unlockedAchievements.length;
    final totalCount = widget.allAchievements.length;
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

  Widget _buildAchievementCard(Achievement achievement, bool isUnlocked) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    achievement.icon,
                    color: isUnlocked ? achievement.color : AppColors.textTertiary,
                    size: 36,
                  ),
                  if (!isUnlocked)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Title
              Text(
                achievement.title,
                style: AppTextStyles.body.copyWith(
                  color: isUnlocked ? achievement.color : AppColors.textTertiary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
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
