/// Application Router Configuration
///
/// Manages app-wide navigation using GoRouter with automatic flow control
/// based on app state (splash, onboarding, main app).
///
/// **Navigation Flow:**
/// 1. **Splash Screen** (first launch only)
///    - Shows app branding
///    - Completes → Onboarding
///
/// 2. **Onboarding** (first-time users)
///    - Tutorial and feature introduction
///    - Completes → Main App
///
/// 3. **Main App** (returning users)
///    - Bottom navigation: Home, Profile, History, Settings
///    - Shell route maintains bottom nav across screens
///
/// **Page Transitions:**
/// - Slide + Fade animation (200ms, easeOutCubic)
/// - Smooth transitions between bottom nav screens
///
/// **Guards:**
/// - Redirect middleware ensures proper flow
/// - Prevents accessing main app before onboarding
/// - Handles deep links gracefully
library;

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/routes.dart';
import '../constants/app_constants.dart';
import '../providers/app_state.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/contact_detail_screen.dart';
import '../../models/unified_models.dart';
import 'navigation_wrapper.dart';

/// Router configuration factory
class AppRouter {
  AppRouter._(); // Private constructor to prevent instantiation

  /// Create and configure the app router
  ///
  /// Sets up routes, redirects, and page transitions
  static GoRouter createRouter() {
    developer.log(
      '🧭 Creating app router configuration',
      name: 'Router.Init',
    );

    return GoRouter(
      initialLocation: AppRoutes.splash,

      /// Global redirect middleware
      ///
      /// Enforces navigation flow based on app state:
      /// - Waits for initialization
      /// - Shows splash on first launch
      /// - Requires onboarding completion
      /// - Redirects to home after onboarding
      redirect: (context, state) {
        final appState = context.read<AppState>();
        final currentRoute = state.uri.path;

        // Wait for AppState to initialize before making navigation decisions
        if (!appState.isInitialized) {
          developer.log(
            '⏳ AppState not initialized - staying on current route',
            name: 'Router.Redirect',
          );
          return null;
        }

        // Handle splash screen (for first launch)
        if (appState.shouldShowSplash && currentRoute != AppRoutes.splash) {
          developer.log(
            '🚀 Redirecting to splash screen (first launch)',
            name: 'Router.Redirect',
          );
          return AppRoutes.splash;
        }

        // After splash, check onboarding for first-time users
        if (!appState.shouldShowSplash &&
            appState.shouldShowOnboarding &&
            currentRoute != AppRoutes.onboarding) {
          developer.log(
            '📚 Redirecting to onboarding (new user)',
            name: 'Router.Redirect',
          );
          return AppRoutes.onboarding;
        }

        // Access main app after onboarding complete
        if (!appState.shouldShowSplash &&
            appState.canAccessMainApp &&
            (currentRoute == AppRoutes.splash || currentRoute == AppRoutes.onboarding)) {
          developer.log(
            '🏠 Redirecting to home (onboarding complete)',
            name: 'Router.Redirect',
          );
          return AppRoutes.home;
        }

        // If user hasn't completed onboarding, always show onboarding
        if (!appState.shouldShowSplash &&
            !appState.hasCompletedOnboarding &&
            currentRoute != AppRoutes.onboarding) {
          developer.log(
            '🎯 User needs onboarding - redirecting from $currentRoute',
            name: 'Router.Redirect',
          );
          return AppRoutes.onboarding;
        }

        developer.log(
          'ℹ️  No redirect needed - staying on $currentRoute',
          name: 'Router.Redirect',
        );
        return null;
      },
      // ========== Route Definitions ==========
      routes: [
        // Splash Screen (first launch only)
        GoRoute(
          path: AppRoutes.splash,
          name: 'splash',
          builder: (context, state) {
            developer.log('📍 Navigated to Splash', name: 'Router.Navigate');
            return const SplashScreen();
          },
        ),

        // Onboarding Flow (new users)
        GoRoute(
          path: AppRoutes.onboarding,
          name: 'onboarding',
          builder: (context, state) {
            developer.log('📍 Navigated to Onboarding', name: 'Router.Navigate');
            return const OnboardingScreen();
          },
        ),

        // Contact Detail Screen (modal/overlay)
        GoRoute(
          path: AppRoutes.contactDetail,
          name: 'contactDetail',
          builder: (context, state) {
            final receivedContact = state.extra as ReceivedContact?;

            developer.log(
              receivedContact != null
                ? '📍 Navigated to Contact Detail: ${receivedContact.contact.name}'
                : '⚠️  Navigated to Contact Detail with no data',
              name: 'Router.Navigate',
            );

            if (receivedContact == null) {
              return const Scaffold(
                body: Center(
                  child: Text('No contact data available'),
                ),
              );
            }

            return ContactDetailScreen(receivedContact: receivedContact);
          },
        ),

        // Main App Shell (with bottom navigation)
        ShellRoute(
          builder: (context, state, child) {
            developer.log(
              'Building navigation shell for: ${state.uri.path}',
              name: 'Router.Shell',
            );
            return NavigationWrapper(child: child);
          },
          routes: [
            // Home Screen
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              pageBuilder: (context, state) {
                developer.log('📍 Navigated to Home', name: 'Router.Navigate');
                return _buildPageWithTransition(
                  context,
                  state,
                  const HomeScreen(),
                );
              },
            ),

            // Profile Screen
            GoRoute(
              path: AppRoutes.profile,
              name: 'profile',
              pageBuilder: (context, state) {
                developer.log('📍 Navigated to Profile', name: 'Router.Navigate');
                return _buildPageWithTransition(
                  context,
                  state,
                  const ProfileScreen(),
                );
              },
            ),

            // History Screen
            GoRoute(
              path: AppRoutes.history,
              name: 'history',
              pageBuilder: (context, state) {
                developer.log('📍 Navigated to History', name: 'Router.Navigate');
                return _buildPageWithTransition(
                  context,
                  state,
                  const HistoryScreen(),
                );
              },
            ),

            // Settings Screen
            GoRoute(
              path: AppRoutes.settings,
              name: 'settings',
              pageBuilder: (context, state) {
                developer.log('📍 Navigated to Settings', name: 'Router.Navigate');
                return _buildPageWithTransition(
                  context,
                  state,
                  const SettingsScreen(),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Build a page with slide + fade transition
  ///
  /// Creates smooth animated transitions between screens
  /// - Slide from right to left
  /// - Fade in simultaneously
  /// - 200ms duration with easeOutCubic curve
  static Page _buildPageWithTransition(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide animation from right to left
        final slideAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0), // Start off-screen to the right
          end: Offset.zero,                // End at normal position
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: animation, // Fade in simultaneously
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: AppDurations.pageTransition),
    );
  }
}