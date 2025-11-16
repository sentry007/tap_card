import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../widgets/tutorial/tutorial_keys.dart';
import '../constants/routes.dart';

class GlassBottomNav extends StatefulWidget {
  const GlassBottomNav({super.key});

  @override
  State<GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends State<GlassBottomNav>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _currentIndex = 0;

  final List<NavItem> _navItems = [
    NavItem(
      icon: CupertinoIcons.home,
      activeIcon: CupertinoIcons.house_fill,
      label: 'Home',
      route: AppRoutes.home,
    ),
    NavItem(
      key: TutorialKeys.bottomNavProfileKey,
      icon: CupertinoIcons.person,
      activeIcon: CupertinoIcons.person_fill,
      label: 'Profile',
      route: AppRoutes.profile,
    ),
    NavItem(
      key: TutorialKeys.bottomNavHistoryKey,
      icon: CupertinoIcons.clock,
      activeIcon: CupertinoIcons.clock_fill,
      label: 'History',
      route: AppRoutes.history,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Set initial index based on current route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentRoute = GoRouterState.of(context).uri.path;
      final index = AppRoutes.getBottomNavIndex(currentRoute);
      if (index >= 0 && index != _currentIndex) {
        setState(() => _currentIndex = index);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Update selected index when route changes (e.g., via programmatic navigation)
    final currentRoute = GoRouterState.of(context).uri.path;
    final routeIndex = AppRoutes.getBottomNavIndex(currentRoute);

    // Only update if it's a valid nav route, otherwise keep current selection
    if (routeIndex >= 0 && routeIndex != _currentIndex) {
      setState(() => _currentIndex = routeIndex);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // Allow re-navigation if coming from non-nav route (_currentIndex could be stale)
    final currentRoute = GoRouterState.of(context).uri.path;
    final routeIndex = AppRoutes.getBottomNavIndex(currentRoute);

    // Prevent re-navigation only if we're on the exact same route
    if (routeIndex == index) return;

    setState(() => _currentIndex = index);
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    context.go(_navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _navItems.length,
                (index) => _buildNavItem(index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isSelected = index == _currentIndex;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final scale = isSelected ? _scaleAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              key: item.key,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      key: ValueKey(isSelected),
                      size: 24,
                      color: isSelected
                          ? AppColors.primaryAction
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected
                          ? AppColors.primaryAction
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    child: Text(item.label),
                  ),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

class NavItem {
  final GlobalKey? key;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  NavItem({
    this.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

class GlassNavIndicator extends StatelessWidget {
  final double width;
  final bool isVisible;

  const GlassNavIndicator({
    super.key,
    required this.width,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isVisible ? width : 0,
      height: 3,
      decoration: BoxDecoration(
        color: AppColors.primaryAction,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAction.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}