/// History Screen
///
/// Displays sharing history with filters, search, and real-time updates.
/// Features:
/// - Real-time sync with HistoryService
/// - Filters: All, Sent, Received, Via Tag, This Week
/// - Search by name/location
/// - Method chips (NFC/QR/Link/Tag)
/// - Enhanced detail modals with sender profiles
/// - Swipe to delete
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/constants/routes.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import '../../widgets/history/method_chip.dart';
import '../../core/constants/app_constants.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _filterController;
  late AnimationController _listController;
  late AnimationController _searchAnimController;

  late Animation<double> _filterSlide;
  late Animation<double> _listFade;
  late Animation<double> _searchScale;

  // Controllers and state
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  String _selectedFilter = 'All';
  bool _isSearching = false;
  bool _isLoading = false;
  String _searchQuery = '';

  final List<String> _filters = ['All', 'Sent', 'Received', 'Via Tag', 'This Week'];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initSearchListener();
    _startAnimations();
    _initHistoryService();
  }

  Future<void> _initHistoryService() async {
    await HistoryService.initialize();
    // Force a setState to trigger rebuild after initialization
    if (mounted) {
      setState(() {});
    }
  }

  void _initAnimations() {
    _filterController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _listController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _searchAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _filterSlide = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _filterController,
      curve: Curves.easeOutCubic,
    ));

    _listFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOut,
    ));

    _searchScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeInOut,
    ));
  }

  void _initSearchListener() {
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _filterController.forward();
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _listController.forward();
    });
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() => _isLoading = false);
      HapticFeedback.lightImpact();
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.text = '';
        _searchQuery = '';
      }
    });
    HapticFeedback.lightImpact();
  }

  void _onFilterSelected(String filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    HapticFeedback.lightImpact();
    _listController.reverse().then((_) {
      if (mounted) _listController.forward();
    });
  }

  List<HistoryEntry> _filterHistoryItems(List<HistoryEntry> items) {
    // Apply text search filter
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        final name = item.displayName.toLowerCase();
        final location = (item.location ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || location.contains(query);
      }).toList();
    }

    // Apply category filter
    switch (_selectedFilter) {
      case 'Sent':
        items = items.where((item) => item.type == HistoryEntryType.sent).toList();
        break;
      case 'Received':
        items = items.where((item) => item.type == HistoryEntryType.received).toList();
        break;
      case 'Via Tag':
        items = items.where((item) => item.type == HistoryEntryType.tag).toList();
        break;
      case 'This Week':
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        items = items.where((item) => item.timestamp.isAfter(weekAgo)).toList();
        break;
      default:
        break;
    }

    return items;
  }

  Future<void> _deleteItem(String itemId) async {
    await HistoryService.deleteEntry(itemId);
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Item deleted'),
          backgroundColor: AppColors.surfaceDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _softDeleteItem(String itemId) async {
    await HistoryService.softDeleteEntry(itemId);
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Moved to archive'),
          backgroundColor: AppColors.surfaceDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primaryAction,
            onPressed: () => HistoryService.restoreEntry(itemId),
          ),
        ),
      );
    }
  }

  void _showItemDetails(HistoryEntry item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: item.type == HistoryEntryType.received ? 0.85 : 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: [0.5, item.type == HistoryEntryType.received ? 0.85 : 0.75, 0.95],
        builder: (context, scrollController) => _buildItemDetailModal(item, scrollController),
      ),
    );
  }

  @override
  void dispose() {
    _filterController.dispose();
    _listController.dispose();
    _searchAnimController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient (full screen behind everything)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBackground,
                    AppColors.surfaceDark,
                  ],
                ),
              ),
            ),
          ),
          // Content scrolls from top
          _buildHistoryGrid(),
          // Filter chips overlay
          Positioned(
            top: statusBarHeight + 80,
            left: 0,
            right: 0,
            child: _buildFilterChips(),
          ),
          // App bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassAppBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar() {
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
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _searchAnimController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _searchScale.value,
                          child: _buildAppBarIcon(
                            _isSearching ? CupertinoIcons.xmark : CupertinoIcons.search,
                            _toggleSearch,
                          ),
                        );
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, -0.5),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(opacity: animation, child: child),
                          );
                        },
                        child: _isSearching
                            ? TextField(
                                key: const Key('search_field'),
                                controller: _searchController,
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
                    SizedBox(width: AppSpacing.sm),
                    _buildAppBarIcon(CupertinoIcons.settings, _openSettings),
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

  Widget _buildFilterChips() {
    return AnimatedBuilder(
      animation: _filterController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_filterSlide.value * 100, 0),
          child: Container(
            height: 36,
            margin: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                final filterColors = _getFilterColors(filter);

                return Container(
                  margin: EdgeInsets.only(right: AppSpacing.sm),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onFilterSelected(filter),
                      borderRadius: BorderRadius.circular(18),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? filterColors['background']!.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? filterColors['border']!
                                    : Colors.white.withOpacity(0.2),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: filterColors['shadow']!.withOpacity(0.2),
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
                                    ? filterColors['text']!
                                    : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
          ),
        );
      },
    );
  }

  Map<String, Color> _getFilterColors(String filter) {
    switch (filter) {
      case 'Sent':
        return {
          'background': AppColors.primaryAction,
          'border': AppColors.primaryAction.withOpacity(0.5),
          'text': AppColors.primaryAction,
          'shadow': AppColors.primaryAction,
        };
      case 'Received':
        return {
          'background': AppColors.success,
          'border': AppColors.success.withOpacity(0.5),
          'text': AppColors.success,
          'shadow': AppColors.success,
        };
      case 'Via Tag':
        return {
          'background': AppColors.secondaryAction,
          'border': AppColors.secondaryAction.withOpacity(0.5),
          'text': AppColors.secondaryAction,
          'shadow': AppColors.secondaryAction,
        };
      case 'This Week':
        return {
          'background': AppColors.highlight,
          'border': AppColors.highlight.withOpacity(0.5),
          'text': AppColors.highlight,
          'shadow': AppColors.highlight,
        };
      default:
        return {
          'background': AppColors.textPrimary,
          'border': AppColors.textPrimary.withOpacity(0.5),
          'text': AppColors.textPrimary,
          'shadow': AppColors.textPrimary,
        };
    }
  }

  Widget _buildHistoryGrid() {
    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _listFade,
          child: RefreshIndicator(
            key: _refreshKey,
            onRefresh: _onRefresh,
            color: AppColors.primaryAction,
            backgroundColor: AppColors.surfaceDark,
            child: _buildGridContent(),
          ),
        );
      },
    );
  }

  Widget _buildGridContent() {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return StreamBuilder<List<HistoryEntry>>(
      stream: HistoryService.historyStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
          return _buildLoadingGrid();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final allItems = snapshot.data ?? [];
        final filteredItems = _filterHistoryItems(allItems);

        if (filteredItems.isEmpty) {
          return _buildEmptyState();
        }

        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: statusBarHeight + 80 + 36 + AppSpacing.xs + AppSpacing.md, // App bar + filter chips + margins + grid padding
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md + 80, // Grid padding + bottom nav space
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) => _buildHistoryCard(filteredItems[index], index),
        );
      },
    );
  }

  Widget _buildHistoryCard(HistoryEntry item, int index) {
    final colors = _getHistoryColors(item.type);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: const Icon(CupertinoIcons.delete, color: AppColors.error, size: 24),
      ),
      onDismissed: (direction) {
        if (item.type == HistoryEntryType.sent) {
          _softDeleteItem(item.id);
        } else {
          _deleteItem(item.id);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showItemDetails(item),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: colors['background'],
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: colors['border']!, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: _buildProfileAvatar(item),
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: _getItemColor(item.type).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              _getTypeIcon(item.type),
                              color: _getItemColor(item.type),
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        item.displayName,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.subtitle,
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MethodChip(method: item.method, fontSize: 9, iconSize: 10),
                          if (item.location != null)
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(CupertinoIcons.location_fill, color: AppColors.textTertiary, size: 10),
                                  SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      item.location!,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textTertiary,
                                        fontSize: 9,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        _formatTimestamp(item.timestamp),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(HistoryEntry item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final radius = size / 2;
        final fontSize = size * 0.5;
        final iconSize = size * 0.6;

        switch (item.type) {
          case HistoryEntryType.sent:
            // Show recipient initial in circle
            final initial = item.recipientName?.isNotEmpty == true
                ? item.recipientName![0].toUpperCase()
                : '?';
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryAction,
                    AppColors.secondaryAction,
                  ],
                ),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );

          case HistoryEntryType.received:
            // Show sender's profile photo or initial
            final profile = item.senderProfile;
            if (profile == null) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Icon(CupertinoIcons.person, color: AppColors.success, size: iconSize),
              );
            }

            if (profile.profileImagePath != null && profile.profileImagePath!.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Image.file(
                  File(profile.profileImagePath!),
                  fit: BoxFit.cover,
                ),
              );
            }

            // Show initial in gradient
            final initial = profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?';
            return Container(
              decoration: BoxDecoration(
                gradient: profile.cardAesthetics.gradient,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );

          case HistoryEntryType.tag:
            // Show tag type text
            return Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryAction.withOpacity(0.2),
                borderRadius: BorderRadius.circular(size * 0.2),
              ),
              child: Center(
                child: Text(
                  item.tagType ?? 'TAG',
                  style: TextStyle(
                    color: AppColors.secondaryAction,
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
        }
      },
    );
  }

  Widget _buildItemDetailModal(HistoryEntry item, ScrollController scrollController) {
    return Container(
      margin: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: _getModalBorderColor(item.type),
                width: 2.0,
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _getItemColor(item.type).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      child: _buildProfileAvatar(item),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getItemColor(item.type).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              item.type.label,
                              style: AppTextStyles.caption.copyWith(
                                color: _getItemColor(item.type),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                _buildDetailRow(CupertinoIcons.arrow_right_arrow_left, 'Method', item.method.label),
                if (item.recipientDevice != null)
                  _buildDetailRow(CupertinoIcons.device_phone_portrait, 'Device', item.recipientDevice!),
                if (item.location != null)
                  _buildDetailRow(CupertinoIcons.location_fill, 'Location', item.location!),
                if (item.tagType != null)
                  _buildDetailRow(CupertinoIcons.tag, 'Tag Type', '${item.tagType} (${item.tagCapacity} bytes)'),
                _buildDetailRow(CupertinoIcons.time, 'Time', _formatDetailTimestamp(item.timestamp)),
                SizedBox(height: AppSpacing.lg),
                _buildModalActions(item),
                // Bottom padding to clear nav bar
                SizedBox(height: MediaQuery.of(context).viewPadding.bottom + AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalActions(HistoryEntry item) {
    switch (item.type) {
      case HistoryEntryType.sent:
        return SizedBox(
          width: double.infinity,
          child: AppButton.outlined(
            text: 'Archive',
            icon: const Icon(CupertinoIcons.archivebox, size: 18),
            onPressed: () {
              Navigator.pop(context);
              _softDeleteItem(item.id);
            },
          ),
        );

      case HistoryEntryType.received:
        return Column(
          children: [
            if (item.senderProfile != null) ...[
              _buildSenderProfileCard(item.senderProfile!),
              SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                Expanded(
                  child: AppButton.outlined(
                    text: 'Delete',
                    icon: const Icon(CupertinoIcons.delete, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteItem(item.id);
                    },
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton.contained(
                    text: 'Save',
                    icon: const Icon(CupertinoIcons.person_add, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      _saveToContacts(item.senderProfile!);
                    },
                  ),
                ),
              ],
            ),
          ],
        );

      case HistoryEntryType.tag:
        return SizedBox(
          width: double.infinity,
          child: AppButton.outlined(
            text: 'Delete',
            icon: const Icon(CupertinoIcons.delete, size: 18),
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(item.id);
            },
          ),
        );
    }
  }

  Widget _buildSenderProfileCard(dynamic profile) {
    return Center(
      child: ProfileCardPreview(
        profile: profile,
        width: MediaQuery.of(context).size.width * 0.85,
        height: 200,
        borderRadius: AppRadius.xl,
        onEmailTap: profile.email != null
          ? () => _launchEmail(profile.email!)
          : null,
        onPhoneTap: profile.phone != null
          ? () => _launchPhone(profile.phone!)
          : null,
        onWebsiteTap: profile.website != null
          ? () => _launchUrl(profile.website!)
          : null,
        onSocialTap: (platform, url) => _launchSocialMedia(platform, url),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(AppSpacing.md),
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
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withOpacity(0.3),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
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
          SizedBox(height: AppSpacing.xl),
          Text(
            _getEmptyStateTitle(),
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: AppSpacing.sm),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              _getEmptyStateMessage(),
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          AppButton.outlined(
            text: 'Start Sharing',
            icon: const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle, size: 60, color: AppColors.error),
          SizedBox(height: AppSpacing.md),
          Text(
            'Error loading history',
            style: AppTextStyles.h3.copyWith(color: AppColors.error),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Map<String, Color> _getHistoryColors(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return {
          'background': AppColors.primaryAction.withOpacity(0.1),
          'border': AppColors.primaryAction.withOpacity(0.3),
        };
      case HistoryEntryType.received:
        return {
          'background': AppColors.success.withOpacity(0.1),
          'border': AppColors.success.withOpacity(0.3),
        };
      case HistoryEntryType.tag:
        return {
          'background': AppColors.secondaryAction.withOpacity(0.1),
          'border': AppColors.secondaryAction.withOpacity(0.3),
        };
    }
  }

  Color _getItemColor(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return AppColors.primaryAction;
      case HistoryEntryType.received:
        return AppColors.success;
      case HistoryEntryType.tag:
        return AppColors.secondaryAction;
    }
  }

  Color _getModalBorderColor(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return AppColors.primaryAction.withOpacity(0.5);
      case HistoryEntryType.received:
        return AppColors.success.withOpacity(0.5);
      case HistoryEntryType.tag:
        return AppColors.secondaryAction.withOpacity(0.5);
    }
  }

  IconData _getTypeIcon(HistoryEntryType type) {
    switch (type) {
      case HistoryEntryType.sent:
        return CupertinoIcons.arrow_up_right;
      case HistoryEntryType.received:
        return CupertinoIcons.arrow_down_left;
      case HistoryEntryType.tag:
        return CupertinoIcons.tag;
    }
  }

  String _getEmptyStateTitle() {
    switch (_selectedFilter) {
      case 'Sent':
        return 'No Sent Contacts';
      case 'Received':
        return 'No Received Contacts';
      case 'Via Tag':
        return 'No NFC Tags Written';
      case 'This Week':
        return 'No Activity This Week';
      default:
        return 'Start Your Journey';
    }
  }

  String _getEmptyStateMessage() {
    switch (_selectedFilter) {
      case 'Sent':
        return 'You haven\'t sent any contacts yet. Tap someone\'s device to start connecting!';
      case 'Received':
        return 'You haven\'t received any contacts yet. Ask someone to share their details with you!';
      case 'Via Tag':
        return 'You haven\'t written to any NFC tags yet. Write your contact info to stickers or cards!';
      case 'This Week':
        return 'No sharing activity in the past week. Time to make some new connections!';
      default:
        return 'Your contact sharing journey starts here. Share your details with a simple tap and watch your network grow!';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  String _formatDetailTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveToContacts(dynamic profile) async {
    HapticFeedback.lightImpact();

    try {
      // Create VCard format
      final vCard = _createVCard(profile);

      // Save to file and share using share_plus
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/contact_${DateTime.now().millisecondsSinceEpoch}.vcf');
      await file.writeAsString(vCard);

      // Share the VCard file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Contact: ${profile.name}',
        text: 'Save ${profile.name} to your contacts',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(CupertinoIcons.checkmark_circle, color: AppColors.success),
                SizedBox(width: 12),
                Text('Opening contact card for ${profile.name}'),
              ],
            ),
            backgroundColor: AppColors.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(CupertinoIcons.exclamationmark_circle, color: AppColors.error),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to save contact: $e')),
              ],
            ),
            backgroundColor: AppColors.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _createVCard(dynamic profile) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:${profile.name}');

    if (profile.title != null && profile.title!.isNotEmpty) {
      buffer.writeln('TITLE:${profile.title}');
    }

    if (profile.company != null && profile.company!.isNotEmpty) {
      buffer.writeln('ORG:${profile.company}');
    }

    if (profile.phone != null && profile.phone!.isNotEmpty) {
      buffer.writeln('TEL:${profile.phone}');
    }

    if (profile.email != null && profile.email!.isNotEmpty) {
      buffer.writeln('EMAIL:${profile.email}');
    }

    if (profile.website != null && profile.website!.isNotEmpty) {
      buffer.writeln('URL:${profile.website}');
    }

    buffer.writeln('END:VCARD');
    return buffer.toString();
  }

  void _openSettings() {
    HapticFeedback.lightImpact();
    context.go(AppRoutes.settings);
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackbar('Could not open phone dialer');
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackbar('Could not open email app');
    }
  }

  Future<void> _launchUrl(String url) async {
    var formattedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      formattedUrl = 'https://$url';
    }

    final uri = Uri.parse(formattedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackbar('Could not open website');
    }
  }

  Future<void> _launchSocialMedia(String platform, String url) async {
    // Handle both full URLs and usernames
    String finalUrl = url;
    if (!url.startsWith('http')) {
      // Convert username to full URL
      finalUrl = _getSocialUrl(platform, url);
    }
    await _launchUrl(finalUrl);
  }

  String _getSocialUrl(String platform, String username) {
    // Remove @ symbol if present
    final cleanUsername = username.startsWith('@') ? username.substring(1) : username;

    switch (platform.toLowerCase()) {
      case 'linkedin':
        return 'https://linkedin.com/in/$cleanUsername';
      case 'twitter':
      case 'x':
        return 'https://twitter.com/$cleanUsername';
      case 'github':
        return 'https://github.com/$cleanUsername';
      case 'instagram':
        return 'https://instagram.com/$cleanUsername';
      case 'behance':
        return 'https://behance.net/$cleanUsername';
      case 'dribbble':
        return 'https://dribbble.com/$cleanUsername';
      case 'tiktok':
        return 'https://tiktok.com/@$cleanUsername';
      case 'youtube':
        return 'https://youtube.com/@$cleanUsername';
      default:
        return cleanUsername; // Assume it's already a URL
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(CupertinoIcons.exclamationmark_circle, color: AppColors.error),
              SizedBox(width: 12),
              Text(message),
            ],
          ),
          backgroundColor: AppColors.surfaceDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
