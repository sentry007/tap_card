import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/constants/routes.dart';

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
  bool _isLoadingMore = false;
  String _searchQuery = '';

  final List<String> _filters = ['All', 'Sent', 'Received', 'QR Scans', 'This Week'];

  // Mock data with more realistic contact sharing entries
  List<HistoryItem> _historyItems = [
    HistoryItem(
      id: '1',
      type: HistoryType.shared,
      contactName: 'John Williams',
      avatar: '👨‍💼',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      deviceInfo: 'iPhone 14 Pro',
      location: 'Coffee Shop',
    ),
    HistoryItem(
      id: '2',
      type: HistoryType.received,
      contactName: 'Sarah Chen',
      avatar: '👩‍💻',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      deviceInfo: 'Galaxy S23',
      location: 'Conference',
    ),
    HistoryItem(
      id: '3',
      type: HistoryType.shared,
      contactName: 'Mike Rodriguez',
      avatar: '👨‍🎨',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      deviceInfo: 'Pixel 7',
      location: 'Co-working Space',
    ),
    HistoryItem(
      id: '4',
      type: HistoryType.received,
      contactName: 'Emily Johnson',
      avatar: '👩‍🔬',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      deviceInfo: 'OnePlus 11',
      location: 'Lab Meeting',
    ),
    HistoryItem(
      id: '5',
      type: HistoryType.shared,
      contactName: 'David Kim',
      avatar: '👨‍🚀',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      deviceInfo: 'iPhone 13',
      location: 'Startup Event',
    ),
    HistoryItem(
      id: '6',
      type: HistoryType.received,
      contactName: 'Anna Martinez',
      avatar: '👩‍🎤',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      deviceInfo: 'Pixel 6a',
      location: 'Music Studio',
    ),
    HistoryItem(
      id: '7',
      type: HistoryType.shared,
      contactName: 'James Wilson',
      avatar: '👨‍🏫',
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
      deviceInfo: 'Galaxy S22',
      location: 'University',
    ),
    HistoryItem(
      id: '8',
      type: HistoryType.received,
      contactName: 'Lisa Brown',
      avatar: '👩‍⚕️',
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
      deviceInfo: 'iPhone 12',
      location: 'Hospital',
    ),
    HistoryItem(
      id: '9',
      type: HistoryType.qr,
      contactName: 'QR Code Scan',
      avatar: '📱',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      deviceInfo: 'Camera',
      location: 'Restaurant',
    ),
    HistoryItem(
      id: '10',
      type: HistoryType.qr,
      contactName: 'Menu QR Scan',
      avatar: '🍕',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      deviceInfo: 'Camera',
      location: 'Pizza Place',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initScrollListener();
    _initSearchListener();
    _startAnimations();
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

  void _initScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreItems();
      }
    });
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
      _filterController.forward();
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      _listController.forward();
    });
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      setState(() => _isLoading = false);
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    // Simulate loading more items
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() => _isLoadingMore = false);
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

    // Animate filter change
    _listController.reverse().then((_) {
      _listController.forward();
    });
  }

  List<HistoryItem> get _filteredItems {
    List<HistoryItem> items = _historyItems;

    // Apply text search filter
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) =>
        item.contactName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        item.location.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply category filter
    switch (_selectedFilter) {
      case 'Sent':
        items = items.where((item) => item.type == HistoryType.shared).toList();
        break;
      case 'Received':
        items = items.where((item) => item.type == HistoryType.received).toList();
        break;
      case 'QR Scans':
        items = items.where((item) => item.type == HistoryType.qr).toList();
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

  void _deleteItem(String itemId) {
    setState(() {
      _historyItems.removeWhere((item) => item.id == itemId);
    });
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Item deleted'),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primaryAction,
          onPressed: () {
            // TODO: Implement undo functionality
          },
        ),
      ),
    );
  }

  void _showItemDetails(HistoryItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildItemDetailModal(item),
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: Column(
          children: [
            _buildGlassAppBar(),
            _buildFilterChips(),
            Expanded(
              child: _buildHistoryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassAppBar() {
    return SafeArea(
      key: const Key('history_appbar_safe_area'),
      bottom: false,
      child: Container(
        key: const Key('history_appbar_container'),
        height: 64,
        margin: const EdgeInsets.all(16),
        color: Colors.transparent,
        child: ClipRRect(
          key: const Key('history_appbar_clip'),
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            key: const Key('history_appbar_backdrop'),
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              key: const Key('history_appbar_content_container'),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
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
                key: const Key('history_appbar_padding'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  key: const Key('history_appbar_row'),
                  children: [
                    AnimatedBuilder(
                      key: const Key('history_appbar_search_animation'),
                      animation: _searchAnimController,
                      builder: (context, child) {
                        return Transform.scale(
                          key: const Key('history_appbar_search_transform'),
                          scale: _searchScale.value,
                          child: _buildAppBarIcon(
                            _isSearching ? Icons.close : Icons.search_rounded,
                            _toggleSearch,
                            'search',
                          ),
                        );
                      },
                    ),
                    const SizedBox(key: Key('history_appbar_search_spacing'), width: 12),
                    Expanded(
                      key: const Key('history_appbar_expanded_content'),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, -0.5),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _isSearching
                            ? TextField(
                                key: const Key('history_appbar_search_field'),
                                controller: _searchController,
                                autofocus: true,
                                style: AppTextStyles.h3.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                cursorColor: AppColors.textPrimary,
                                decoration: InputDecoration(
                                  hintText: 'Search history...',
                                  hintStyle: AppTextStyles.h3.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTertiary,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  filled: false,
                                ),
                                onChanged: (value) {
                                  setState(() => _searchQuery = value);
                                },
                              )
                            : Text(
                                key: const Key('history_appbar_title'),
                                'History',
                                style: AppTextStyles.h3.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                    const SizedBox(key: Key('history_appbar_settings_spacing'), width: 12),
                    _buildAppBarIcon(Icons.settings_outlined, _openSettings, 'settings'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap, [String? keyName]) {
    final key = keyName ?? 'icon';
    return Material(
      key: Key('history_appbar_${key}_material'),
      color: Colors.transparent,
      child: InkWell(
        key: Key('history_appbar_${key}_inkwell'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: Key('history_appbar_${key}_container'),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            key: Key('history_appbar_${key}_icon'),
            icon,
            color: AppColors.textSecondary,
            size: 20,
          ),
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
            height: 36, // Reduced height to minimize wasted space
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                final filterColors = _getFilterColors(filter);

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onFilterSelected(filter),
                      borderRadius: BorderRadius.circular(18), // Adjusted for smaller height
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, // Reduced horizontal padding
                              vertical: 6,    // Reduced vertical padding
                            ),
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
                            child: Text(
                              filter,
                              style: AppTextStyles.caption.copyWith( // Use caption for smaller text
                                color: isSelected
                                    ? filterColors['text']!
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 13, // Slightly smaller font
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
      case 'QR Scans':
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
      default: // 'All' and any other filters
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
    final filteredItems = _filteredItems;

    if (_isLoading) {
      return _buildLoadingGrid();
    }

    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: filteredItems.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index < filteredItems.length) {
          return _buildHistoryCard(filteredItems[index], index);
        } else {
          return _buildLoadingCard();
        }
      },
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => _buildLoadingCard(),
    );
  }

  Widget _buildLoadingCard() {
    return ClipRRect(
      key: const Key('history_loading_card_clip'),
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        key: const Key('history_loading_card_backdrop'),
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          key: const Key('history_loading_card_container'),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            key: const Key('history_loading_card_column'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                key: const Key('history_loading_card_avatar_placeholder'),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(key: Key('history_loading_card_avatar_spacing'), height: 12),
              Container(
                key: const Key('history_loading_card_name_placeholder'),
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(key: Key('history_loading_card_name_spacing'), height: 8),
              Container(
                key: const Key('history_loading_card_details_placeholder'),
                width: 60,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(HistoryItem item, int index) {
    final colors = _getHistoryColors(item.type);
    final icon = _getHistoryIcon(item.type);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          Icons.delete_outline,
          color: AppColors.error,
          size: 24,
        ),
      ),
      onDismissed: (direction) {
        _deleteItem(item.id);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showItemDetails(item),
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: colors['background'],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors['border']!,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        key: const Key('history_card_header_row'),
                        children: [
                          Text(
                            key: const Key('history_card_avatar_text'),
                            item.avatar,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const Spacer(key: Key('history_card_header_spacer')),
                          Container(
                            key: const Key('history_card_type_badge'),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _getItemColor(item.type).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              key: const Key('history_card_type_icon'),
                              _getTypeIcon(item.type),
                              color: _getItemColor(item.type),
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.contactName,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_getTypeLabel(item.type)} • ${item.deviceInfo}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: AppColors.textTertiary,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.people_outline_rounded,
                    size: 60,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _getEmptyStateTitle(),
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _getEmptyStateMessage(),
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          AppButton.outlined(
            text: 'Start Sharing',
            icon: const Icon(Icons.nfc, size: 20),
            onPressed: () {
              // TODO: Navigate to sharing screen
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetailModal(HistoryItem item) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      item.avatar,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.contactName,
                            style: AppTextStyles.h2.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getItemColor(item.type).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _getTypeLabel(item.type),
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
                const SizedBox(height: 24),
                _buildDetailRow(Icons.smartphone, 'Device', item.deviceInfo),
                _buildDetailRow(Icons.location_on, 'Location', item.location),
                _buildDetailRow(Icons.access_time, 'Time', _formatDetailTimestamp(item.timestamp)),
                const SizedBox(height: 24),
                _buildModalActions(item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalActions(HistoryItem item) {
    switch (item.type) {
      case HistoryType.shared:
        // For sent cards: only soft delete
        return SizedBox(
          width: double.infinity,
          child: AppButton.outlined(
            text: 'Soft Delete',
            icon: const Icon(Icons.archive_outlined, size: 18),
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(item.id);
            },
          ),
        );

      case HistoryType.received:
        // For received cards: delete and open in contacts
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AppButton.outlined(
                    text: 'Delete',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteItem(item.id);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.contained(
                    text: 'Contacts',
                    icon: const Icon(Icons.contacts, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      _addToContacts(item);
                    },
                  ),
                ),
              ],
            ),
          ],
        );

      case HistoryType.qr:
        // For QR scans: delete and share our contact info
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AppButton.outlined(
                    text: 'Delete',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteItem(item.id);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.contained(
                    text: 'Share Card',
                    icon: const Icon(Icons.nfc, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      _shareMyCard();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  Color _getItemColor(HistoryType type) {
    switch (type) {
      case HistoryType.shared:
        return AppColors.primaryAction;
      case HistoryType.received:
        return AppColors.success;
      case HistoryType.qr:
        return AppColors.secondaryAction;
    }
  }

  IconData _getTypeIcon(HistoryType type) {
    switch (type) {
      case HistoryType.shared:
        return Icons.send;
      case HistoryType.received:
        return Icons.call_received;
      case HistoryType.qr:
        return Icons.qr_code_scanner;
    }
  }

  String _getTypeLabel(HistoryType type) {
    switch (type) {
      case HistoryType.shared:
        return 'Sent';
      case HistoryType.received:
        return 'Received';
      case HistoryType.qr:
        return 'QR Scan';
    }
  }

  Map<String, Color> _getHistoryColors(HistoryType type) {
    switch (type) {
      case HistoryType.shared:
        return {
          'background': AppColors.primaryAction.withOpacity(0.1),
          'border': AppColors.primaryAction.withOpacity(0.3),
          'iconBg': AppColors.primaryAction.withOpacity(0.2),
          'icon': AppColors.primaryAction,
          'text': AppColors.primaryAction,
        };
      case HistoryType.received:
        return {
          'background': AppColors.success.withOpacity(0.1),
          'border': AppColors.success.withOpacity(0.3),
          'iconBg': AppColors.success.withOpacity(0.2),
          'icon': AppColors.success,
          'text': AppColors.success,
        };
      case HistoryType.qr:
        return {
          'background': AppColors.secondaryAction.withOpacity(0.1),
          'border': AppColors.secondaryAction.withOpacity(0.3),
          'iconBg': AppColors.secondaryAction.withOpacity(0.2),
          'icon': AppColors.secondaryAction,
          'text': AppColors.secondaryAction,
        };
    }
  }

  IconData _getHistoryIcon(HistoryType type) {
    switch (type) {
      case HistoryType.shared:
        return Icons.send;
      case HistoryType.received:
        return Icons.call_received;
      case HistoryType.qr:
        return Icons.qr_code_scanner;
    }
  }

  String _getEmptyStateTitle() {
    switch (_selectedFilter) {
      case 'Sent':
        return 'No Sent Contacts';
      case 'Received':
        return 'No Received Contacts';
      case 'QR Scans':
        return 'No QR Scans';
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
      case 'QR Scans':
        return 'You haven\'t scanned any QR codes yet. Look for QR codes to scan and connect!';
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

  void _addToContacts(HistoryItem item) {
    HapticFeedback.lightImpact();
    // TODO: Implement add to contacts functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.contactName} will be added to contacts'),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareMyCard() {
    HapticFeedback.lightImpact();
    // TODO: Implement share my card functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Opening share card...'),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openSettings() {
    HapticFeedback.lightImpact();
    context.go(AppRoutes.settings);
  }
}

class HistoryItem {
  final String id;
  final HistoryType type;
  final String contactName;
  final String avatar;
  final DateTime timestamp;
  final String deviceInfo;
  final String location;

  HistoryItem({
    required this.id,
    required this.type,
    required this.contactName,
    required this.avatar,
    required this.timestamp,
    required this.deviceInfo,
    required this.location,
  });
}

enum HistoryType {
  shared,
  received,
  qr,
}