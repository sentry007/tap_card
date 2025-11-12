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
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/constants/routes.dart';
import '../../core/models/profile_models.dart';
import '../../models/history_models.dart';
import '../../services/history_service.dart';
import '../../services/contact_service.dart';
import '../../services/firebase_analytics_service.dart';
import '../../widgets/history/method_chip.dart';
import '../../widgets/history/history_card.dart';
import '../../widgets/history/history_detail_modal.dart';
import '../../widgets/history/history_states.dart';
import '../../widgets/history/history_app_bar.dart';
import '../../widgets/history/permission_banner.dart';
import '../../core/constants/app_constants.dart';

class HistoryScreen extends StatefulWidget {
  final String? initialEntryId;

  const HistoryScreen({super.key, this.initialEntryId});

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
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  String _selectedFilter = 'All';
  bool _isSearching = false;
  bool _isLoading = false;
  String _searchQuery = '';
  bool?
      _hasContactsPermission; // null = checking, false = denied, true = granted
  bool _hasShownInitialModal = false;

  final List<String> _filters = [
    'All',
    'NFC Tags',
    'Today',
    'This Week',
    'This Month'
  ];

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
    // Check if permission is already granted (silent check)
    await _checkContactsPermission();
    // Force a setState to trigger rebuild after initialization
    if (mounted) {
      setState(() {});
    }
  }

  /// Check if contacts permission is already granted (no dialog)
  Future<void> _checkContactsPermission() async {
    final hasPermission = await ContactService.hasContactsPermission();
    if (mounted) {
      setState(() {
        _hasContactsPermission = hasPermission;
      });
    }

    // If already granted, scan immediately using HistoryService
    if (hasPermission) {
      if (kDebugMode) {
        print('📇 [History] Permission already granted, scanning automatically...');
      }
      await HistoryService.scanDeviceContacts();
    } else {
      if (kDebugMode) {
        print('📇 [History] Permission not granted, showing banner...');
      }
    }
  }

  /// Request contacts permission explicitly (shows dialog)
  Future<void> _requestContactsPermission() async {
    if (kDebugMode) {
      print('📇 [History] User tapped "Allow Access" button');
    }
    HapticFeedback.lightImpact();

    // This will show the permission dialog
    await HistoryService.scanDeviceContacts();

    // Update permission state after scan attempt
    final hasPermission = await ContactService.hasContactsPermission();
    if (mounted) {
      setState(() {
        _hasContactsPermission = hasPermission;
      });
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

    // Scan contacts for received TapCard contacts
    await HistoryService.scanDeviceContacts();

    await Future.delayed(const Duration(milliseconds: 500));
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
      case 'NFC Tags':
        // Only show NFC tag writes
        items =
            items.where((item) => item.type == HistoryEntryType.tag).toList();
        break;
      case 'Today':
        // Last 24 hours
        final dayAgo = DateTime.now().subtract(const Duration(days: 1));
        items = items.where((item) => item.timestamp.isAfter(dayAgo)).toList();
        break;
      case 'This Week':
        // Last 7 days
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        items = items.where((item) => item.timestamp.isAfter(weekAgo)).toList();
        break;
      case 'This Month':
        // Last 30 days
        final monthAgo = DateTime.now().subtract(const Duration(days: 30));
        items =
            items.where((item) => item.timestamp.isAfter(monthAgo)).toList();
        break;
      default:
        // 'All' - show both tags and received (exclude sent)
        items =
            items.where((item) => item.type != HistoryEntryType.sent).toList();
        break;
    }

    return items;
  }

  Future<void> _deleteItem(String itemId,
      {bool isReceivedEntry = false}) async {
    final isScannedContact = itemId.startsWith('contact_');

    // HistoryService handles both regular entries and scanned contacts
    // For scanned contacts, it automatically rescans and updates the stream
    final success = await HistoryService.deleteEntry(itemId);

    // Show appropriate feedback
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: success
                      ? AppColors.success.withOpacity(0.15)
                      : AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: success
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  isScannedContact
                      ? (success
                          ? 'Contact deleted from device and history'
                          : 'Failed to delete contact - permission may be required')
                      : (isReceivedEntry
                          ? 'Contact and history deleted'
                          : 'Item deleted'),
                ),
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
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
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryAction.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryAction.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Text('Moved to archive'),
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
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

    // Track contact viewed for received entries using Firebase Analytics
    if (item.type == HistoryEntryType.received &&
        item.senderProfile?.id != null) {
      FirebaseAnalyticsService.logContactViewed(
        profileId: item.senderProfile!.id,
        source: 'history',
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: item.type == HistoryEntryType.received ? 0.85 : 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: [
          0.5,
          item.type == HistoryEntryType.received ? 0.85 : 0.75,
          0.95
        ],
        builder: (context, scrollController) => HistoryDetailModal(
          item: item,
          scrollController: scrollController,
          onArchive: () {
            Navigator.pop(context);
            _softDeleteItem(item.id);
          },
          onDelete: () {
            Navigator.pop(context);
            if (item.type == HistoryEntryType.sent) {
              _softDeleteItem(item.id);
            } else {
              _deleteItem(item.id,
                  isReceivedEntry: item.type == HistoryEntryType.received);
            }
          },
          onSaveToContacts: (profile) => _saveToContacts(profile),
          onLaunchUrl: (url) => _launchUrl(url),
          onLaunchEmail: (email) => _launchEmail(email),
          onLaunchPhone: (phone) => _launchPhone(phone),
          onLaunchSocialMedia: (platform, url) =>
              _launchSocialMedia(platform, url),
        ),
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
            child: HistoryGlassAppBar(
              isSearching: _isSearching,
              onSearchToggle: _toggleSearch,
              onSettingsTap: _openSettings,
              searchController: _searchController,
              searchScale: _searchScale,
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _searchAnimController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _searchScale.value,
                          child: _buildAppBarIcon(
                            _isSearching
                                ? CupertinoIcons.xmark
                                : CupertinoIcons.search,
                            _toggleSearch,
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
                    const SizedBox(width: AppSpacing.sm),
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
            margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                final filterColors = _getFilterColors(filter);

                return Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                                        color: filterColors['shadow']!
                                            .withOpacity(0.2),
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
          ),
        );
      },
    );
  }

  Map<String, Color> _getFilterColors(String filter) {
    switch (filter) {
      case 'NFC Tags':
        return {
          'background': AppColors.secondaryAction,
          'border': AppColors.secondaryAction.withOpacity(0.5),
          'text': AppColors.secondaryAction,
          'shadow': AppColors.secondaryAction,
        };
      case 'Today':
        return {
          'background': AppColors.success,
          'border': AppColors.success.withOpacity(0.5),
          'text': AppColors.success,
          'shadow': AppColors.success,
        };
      case 'This Week':
        return {
          'background': AppColors.highlight,
          'border': AppColors.highlight.withOpacity(0.5),
          'text': AppColors.highlight,
          'shadow': AppColors.highlight,
        };
      case 'This Month':
        return {
          'background': AppColors.primaryAction,
          'border': AppColors.primaryAction.withOpacity(0.5),
          'text': AppColors.primaryAction,
          'shadow': AppColors.primaryAction,
        };
      default:
        // 'All' filter
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
          return const HistoryLoadingGrid();
        }

        if (snapshot.hasError) {
          return HistoryErrorState(error: snapshot.error.toString());
        }

        // HistoryService already returns merged data (history + scanned contacts)
        final allItems = snapshot.data ?? [];
        final filteredItems = _filterHistoryItems(allItems);

        if (kDebugMode) {
          print('📊 [History] Build - allItems: ${allItems.length}, filteredItems: ${filteredItems.length}');
          print('📊 [History] Filtered item names: ${filteredItems.map((e) => e.displayName).take(10).join(", ")}');
        }

        // Auto-open modal if initialEntryId is provided
        if (widget.initialEntryId != null && !_hasShownInitialModal) {
          _hasShownInitialModal = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final entry = allItems.firstWhere(
              (e) => e.id == widget.initialEntryId,
              orElse: () => allItems.first,
            );
            _showItemDetails(entry);
          });
        }

        if (filteredItems.isEmpty) {
          return HistoryEmptyState(selectedFilter: _selectedFilter);
        }

        return Stack(
          children: [
            GridView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: statusBarHeight +
                    80 +
                    36 +
                    AppSpacing.xs +
                    AppSpacing
                        .md, // App bar + filter chips + margins + grid padding
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
              itemBuilder: (context, index) => HistoryCard(
                item: filteredItems[index],
                onTap: () => _showItemDetails(filteredItems[index]),
                onDelete: () {
                  final item = filteredItems[index];
                  if (item.type == HistoryEntryType.sent) {
                    _softDeleteItem(item.id);
                  } else {
                    _deleteItem(item.id,
                        isReceivedEntry: item.type == HistoryEntryType.received);
                  }
                },
              ),
            ),
            // Permission banner (shows when permission not granted)
            if (_hasContactsPermission == false)
              ContactPermissionBanner(
                onAllowAccess: _requestContactsPermission,
                statusBarHeight: statusBarHeight,
              ),
          ],
        );
      },
    );
  }

  /// Permission banner shown when contacts access not granted
  Widget _buildPermissionBanner(double statusBarHeight) {
    return Positioned(
      top: statusBarHeight + 80 + 36 + AppSpacing.xs + AppSpacing.md,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppColors.primaryAction.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      CupertinoIcons.person_2_square_stack,
                      color: AppColors.primaryAction,
                      size: 24,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Enable Contact Scanning',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Atlas Linq can detect contacts you\'ve received by scanning your device contacts for Atlas Linq URLs.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: AppColors.primaryAction,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    onPressed: _requestContactsPermission,
                    child: const Text(
                      'Allow Access to Contacts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(HistoryEntry item, int index) {
    final colors = _getHistoryColors(item.type);

    // Debug: Log if tag entry is missing location
    if (item.type == HistoryEntryType.tag && item.location == null) {
      print(
          '⚠️ [History] Tag entry missing location: ${item.displayName} (${item.id})');
    }

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child:
            const Icon(CupertinoIcons.delete, color: AppColors.error, size: 24),
      ),
      onDismissed: (direction) {
        if (item.type == HistoryEntryType.sent) {
          _softDeleteItem(item.id);
        } else {
          _deleteItem(item.id,
              isReceivedEntry: item.type == HistoryEntryType.received);
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
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                            padding: const EdgeInsets.all(AppSpacing.xs),
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
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        item.displayName,
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.subtitle,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MethodChip(
                              method: item.method, fontSize: 9, iconSize: 10),
                          if (item.location != null)
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(CupertinoIcons.location_fill,
                                      color: AppColors.textTertiary, size: 10),
                                  const SizedBox(width: AppSpacing.xs),
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
                gradient: const LinearGradient(
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
                child: Icon(CupertinoIcons.person,
                    color: AppColors.success, size: iconSize),
              );
            }

            if (profile.profileImagePath != null &&
                profile.profileImagePath!.isNotEmpty) {
              final isNetworkImage =
                  profile.profileImagePath!.startsWith('http://') ||
                      profile.profileImagePath!.startsWith('https://');

              return ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: isNetworkImage
                    ? CachedNetworkImage(
                        imageUrl: profile.profileImagePath!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.withOpacity(0.2),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          CupertinoIcons.person,
                          color: AppColors.success,
                          size: iconSize,
                        ),
                      )
                    : Image.file(
                        File(profile.profileImagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            CupertinoIcons.person,
                            color: AppColors.success,
                            size: iconSize,
                          );
                        },
                      ),
              );
            }

            // Show initial in gradient
            final initial =
                profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?';
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
            // Show NFC tag icon with type badge
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.secondaryAction,
                        AppColors.highlight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.tag_fill,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                ),
                // Tag type badge (NTAG213/215/216)
                if (item.tagType != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.highlight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 0.5),
                      ),
                      child: Text(
                        item.tagType!.replaceAll('NTAG', ''),
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            );
        }
      },
    );
  }


  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon column with fixed width
          SizedBox(
            width: 24,
            child: Icon(
              icon,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Label column with fixed width
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Value takes remaining space
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
              maxLines: 3,
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
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: AppButton.outlined(
                    text: 'Delete',
                    icon: const Icon(CupertinoIcons.delete, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteItem(item.id,
                          isReceivedEntry:
                              item.type == HistoryEntryType.received);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
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
              _deleteItem(item.id,
                  isReceivedEntry: item.type == HistoryEntryType.received);
            },
          ),
        );
    }
  }

  Widget _buildSenderProfileCard(dynamic profile) {
    // Debug logging to verify profile data
    print('🎴 [History] Rendering profile card');
    print('   • Profile Name: ${profile.name}');
    print('   • Profile Type: ${profile.type?.label ?? "unknown"}');
    print('   • Has Email: ${profile.email != null}');
    print('   • Has Phone: ${profile.phone != null}');
    print('   • Has Aesthetics: ${profile.cardAesthetics != null}');
    print('   • Primary Color: ${profile.cardAesthetics?.primaryColor}');
    print('   • Has Image: ${profile.profileImagePath != null}');

    return Center(
      child: ProfileCardPreview(
        profile: profile,
        width: MediaQuery.of(context).size.width * 0.92,
        height: 180,
        borderRadius: AppRadius.xl,
        onEmailTap:
            profile.email != null ? () => _launchEmail(profile.email!) : null,
        onPhoneTap:
            profile.phone != null ? () => _launchPhone(profile.phone!) : null,
        onWebsiteTap:
            profile.website != null ? () => _launchUrl(profile.website!) : null,
        onSocialTap: (platform, url) => _launchSocialMedia(platform, url),
        onCustomLinkTap: (title, url) => _launchUrl(url),
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

  String _formatTagInfo(HistoryEntry item) {
    // Format tag information with type, capacity, and payload type
    final tagType = item.tagType ?? 'Unknown';
    final capacity = item.tagCapacity;
    final payloadType = item.payloadType;

    // Build the info string
    final parts = <String>[tagType];

    if (capacity != null) {
      parts.add('$capacity bytes');
    }

    if (payloadType != null) {
      final payloadLabel = payloadType == 'dual' ? 'Full card' : 'Mini card';
      parts.add(payloadLabel);
    }

    return parts.join(' • ');
  }

  String _formatDetailTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    // Today: Show "Today at 2:30 PM"
    if (diff.inDays == 0 && timestamp.day == now.day) {
      final hour = timestamp.hour > 12
          ? timestamp.hour - 12
          : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return 'Today at $hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    }

    // Yesterday: Show "Yesterday at 2:30 PM"
    if (diff.inDays == 1 || (diff.inDays == 0 && timestamp.day != now.day)) {
      final hour = timestamp.hour > 12
          ? timestamp.hour - 12
          : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return 'Yesterday at $hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    }

    // This week (within 7 days): Show "Mon, 2:30 PM"
    if (diff.inDays < 7) {
      final weekday = [
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat'
      ][timestamp.weekday % 7];
      final hour = timestamp.hour > 12
          ? timestamp.hour - 12
          : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return '$weekday, $hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    }

    // This year: Show "Jan 11, 2:30 PM"
    if (timestamp.year == now.year) {
      final month = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][timestamp.month - 1];
      final hour = timestamp.hour > 12
          ? timestamp.hour - 12
          : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return '$month ${timestamp.day}, $hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    }

    // Older: Show "Jan 11, 2024"
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][timestamp.month - 1];
    return '$month ${timestamp.day}, ${timestamp.year}';
  }

  Future<void> _saveToContacts(dynamic profile) async {
    HapticFeedback.lightImpact();

    try {
      // Create VCard format
      final vCard = _createVCard(profile);

      // Save to file and share using share_plus
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/contact_${DateTime.now().millisecondsSinceEpoch}.vcf');
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
            content: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.checkmark_circle,
                          color: AppColors.success),
                      SizedBox(width: 12),
                      Expanded(
                          child:
                              Text('Opening contact card for ${profile.name}')),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.exclamationmark_circle,
                          color: AppColors.error),
                      SizedBox(width: 12),
                      Expanded(child: Text('Failed to save contact: $e')),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
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
    try {
      var formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        formattedUrl = 'https://$url';
      }

      final uri = Uri.parse(formattedUrl);
      // Skip canLaunchUrl check - it's unreliable and may return false even when launchUrl works
      // Just try to launch directly and handle errors
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Show error only if launchUrl actually fails
      _showErrorSnackbar('Could not open website');
    }
  }

  Future<void> _launchSocialMedia(String platform, String url) async {
    try {
      // 1. Try to open native app first
      final appUri = _getSocialAppUri(platform, url);
      if (appUri != null && await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }

      // 2. Fall back to web URL
      String finalUrl = url;
      if (!url.startsWith('http')) {
        finalUrl = _getSocialUrl(platform, url);
      }
      await _launchUrl(finalUrl);
    } catch (e) {
      // If all fails, show error
      _showErrorSnackbar('Could not open $platform link');
    }
  }

  /// Get native app URI for social platform
  /// Returns null if platform doesn't support app schemes
  Uri? _getSocialAppUri(String platform, String username) {
    final cleanUsername =
        username.startsWith('@') ? username.substring(1) : username;

    // Skip if already a full URL
    if (username.startsWith('http')) return null;

    try {
      switch (platform.toLowerCase()) {
        case 'instagram':
          return Uri.parse('instagram://user?username=$cleanUsername');
        case 'twitter':
        case 'x':
          return Uri.parse('twitter://user?screen_name=$cleanUsername');
        case 'linkedin':
          return Uri.parse('linkedin://profile/$cleanUsername');
        case 'github':
          return Uri.parse('github://$cleanUsername');
        case 'tiktok':
          return Uri.parse('tiktok://user?username=$cleanUsername');
        case 'youtube':
          return Uri.parse('youtube://user/$cleanUsername');
        case 'facebook':
          return Uri.parse('fb://profile/$cleanUsername');
        case 'snapchat':
          return Uri.parse('snapchat://add/$cleanUsername');
        case 'behance':
        case 'dribbble':
        case 'discord':
        case 'twitch':
          // These don't have reliable user schemes
          return null;
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  String _getSocialUrl(String platform, String username) {
    // Remove @ symbol if present
    final cleanUsername =
        username.startsWith('@') ? username.substring(1) : username;

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
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.exclamationmark_circle,
                        color: AppColors.error),
                    SizedBox(width: 12),
                    Expanded(child: Text(message)),
                  ],
                ),
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Get color for profile type badge
  Color _getProfileTypeColor(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return Colors.blue;
      case ProfileType.professional:
        return Colors.green;
      case ProfileType.custom:
        return Colors.purple;
    }
  }

  /// Get icon for profile type badge
  IconData _getProfileTypeIcon(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return CupertinoIcons.person;
      case ProfileType.professional:
        return CupertinoIcons.briefcase;
      case ProfileType.custom:
        return CupertinoIcons.star;
    }
  }
    }