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
import '../../utils/logger.dart';
import '../../utils/snackbar_helper.dart';
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
      Logger.debug('Permission already granted, scanning automatically...', name: 'History');
      await HistoryService.scanDeviceContacts();
    } else {
      Logger.debug('Permission not granted, showing banner...', name: 'History');
    }
  }

  /// Request contacts permission explicitly (shows dialog)
  Future<void> _requestContactsPermission() async {
    Logger.info('User tapped "Allow Access" button', name: 'History');
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
      if (success) {
        // Show success message
        SnackbarHelper.showSuccess(
          context,
          message: isScannedContact
              ? 'Contact deleted from device and history'
              : (isReceivedEntry
                  ? 'Contact and history deleted'
                  : 'Item deleted'),
        );
      } else {
        // Show error message
        SnackbarHelper.showError(
          context,
          message: isScannedContact
              ? 'Failed to delete contact - it may have been manually removed'
              : 'Failed to delete item - permission may be required',
        );
      }
    }
  }

  Future<void> _softDeleteItem(String itemId) async {
    await HistoryService.softDeleteEntry(itemId);
    HapticFeedback.mediumImpact();
    if (mounted) {
      SnackbarHelper.show(
        context,
        message: 'Moved to archive',
        type: SnackbarType.info,
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primaryAction,
          onPressed: () => HistoryService.restoreEntry(itemId),
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
          'border': AppColors.secondaryAction.withValues(alpha: 0.5),
          'text': AppColors.secondaryAction,
          'shadow': AppColors.secondaryAction,
        };
      case 'Today':
        return {
          'background': AppColors.success,
          'border': AppColors.success.withValues(alpha: 0.5),
          'text': AppColors.success,
          'shadow': AppColors.success,
        };
      case 'This Week':
        return {
          'background': AppColors.highlight,
          'border': AppColors.highlight.withValues(alpha: 0.5),
          'text': AppColors.highlight,
          'shadow': AppColors.highlight,
        };
      case 'This Month':
        return {
          'background': AppColors.primaryAction,
          'border': AppColors.primaryAction.withValues(alpha: 0.5),
          'text': AppColors.primaryAction,
          'shadow': AppColors.primaryAction,
        };
      default:
        // 'All' filter
        return {
          'background': AppColors.textPrimary,
          'border': AppColors.textPrimary.withValues(alpha: 0.5),
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

        Logger.debug('Build - allItems: ${allItems.length}, filteredItems: ${filteredItems.length}\n  Filtered item names: ${filteredItems.map((e) => e.displayName).take(10).join(", ")}', name: 'History');

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
        SnackbarHelper.showSuccess(
          context,
          message: 'Opening contact card for ${profile.name}',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          message: 'Failed to save contact: $e',
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
      SnackbarHelper.showError(context, message: message);
    }
  }

}