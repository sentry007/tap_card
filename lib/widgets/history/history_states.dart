/// History Screen State Widgets
///
/// Loading, empty, and error state widgets for the History screen
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/constants/app_constants.dart';

/// Loading grid with skeleton cards
class HistoryLoadingGrid extends StatelessWidget {
  const HistoryLoadingGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget with filter-specific messages
class HistoryEmptyState extends StatelessWidget {
  final String selectedFilter;

  const HistoryEmptyState({
    super.key,
    required this.selectedFilter,
  });

  String _getEmptyStateTitle() {
    switch (selectedFilter) {
      case 'NFC Tags':
        return 'No NFC Tags Written';
      case 'Today':
        return 'No Activity Today';
      case 'This Week':
        return 'No Activity This Week';
      case 'This Month':
        return 'No Activity This Month';
      default:
        return 'Start Your Journey';
    }
  }

  String _getEmptyStateMessage() {
    switch (selectedFilter) {
      case 'NFC Tags':
        return 'You haven\'t written to any NFC tags yet. Write your contact info to stickers or cards to get started!';
      case 'Today':
        return 'No sharing activity today. Tap an NFC tag or device to start connecting!';
      case 'This Week':
        return 'No sharing activity this week. Time to make some new connections!';
      case 'This Month':
        return 'No sharing activity this month. Write to tags or receive contacts with a simple tap!';
      default:
        return 'Your NFC journey starts here. Write to tags and receive contacts with a simple tap!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                  child: const Icon(
                    CupertinoIcons.person_2,
                    size: 60,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            _getEmptyStateTitle(),
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              _getEmptyStateMessage(),
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.outlined(
            text: 'Start Sharing',
            icon: const Icon(CupertinoIcons.antenna_radiowaves_left_right,
                size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// Error state widget
class HistoryErrorState extends StatelessWidget {
  final String error;

  const HistoryErrorState({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle,
              size: 60, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Error loading history',
            style: AppTextStyles.h3.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
