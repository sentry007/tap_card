/// History Screen Glass App Bar
///
/// Animated glassmorphic app bar with search functionality
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../core/constants/app_constants.dart';

/// Glassmorphic app bar with search animation
class HistoryGlassAppBar extends StatelessWidget {
  final bool isSearching;
  final VoidCallback onSearchToggle;
  final VoidCallback onSettingsTap;
  final TextEditingController searchController;
  final Animation<double> searchScale;

  const HistoryGlassAppBar({
    super.key,
    required this.isSearching,
    required this.onSearchToggle,
    required this.onSettingsTap,
    required this.searchController,
    required this.searchScale,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.only(
        top: statusBarHeight + AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
      ),
      child: SizedBox(
        height: 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: searchScale,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: searchScale.value,
                          child: _buildAppBarIcon(
                            isSearching
                                ? CupertinoIcons.xmark
                                : CupertinoIcons.search,
                            onSearchToggle,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, -0.5),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                                opacity: animation, child: child),
                          );
                        },
                        child: isSearching
                            ? TextField(
                                key: const Key('search_field'),
                                controller: searchController,
                                autofocus: true,
                                style: AppTextStyles.h3.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                cursorColor: AppColors.primaryAction,
                                decoration: InputDecoration(
                                  hintText: 'Search history...',
                                  hintStyle: AppTextStyles.h3.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryAction,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  filled: false,
                                ),
                              )
                            : Text(
                                key: const Key('title'),
                                'History',
                                style: AppTextStyles.h3.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _buildAppBarIcon(CupertinoIcons.settings, onSettingsTap),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}
