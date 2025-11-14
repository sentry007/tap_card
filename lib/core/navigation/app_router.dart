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
import '../services/auth_service.dart';
import '../../utils/logger.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/insights/insights_screen.dart';
import '../../screens/contact_detail_screen.dart';
import '../../models/unified_models.dart';
import '../../services/tutorial_service.dart';
import '../../widgets/tutorial/tutorial.dart';
import 'navigation_wrapper.dart';

/// Router configuration factory
class AppRouter {
  AppRouter._(); // Private constructor to prevent instantiation

  /// Create and configure the app router
  ///
  /// Sets up routes, redirects, and page transitions
  ///
  /// [appState] - The global app state that coordinates auth and profile state
  static GoRouter createRouter(AppState appState) {
    Logger.info('Creating app router configuration\n  Router will listen to AppState for refresh events', name: 'ROUTER');

    return GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: appState, // Listen to AppState changes (auth + profiles)

      /// Global redirect middleware
      ///
      /// Enforces navigation flow based on coordinated auth and profile state:
      /// - Waits for both auth and profiles to be ready
      /// - Shows splash/auth screen if not authenticated
      /// - Requires onboarding completion
      /// - Redirects to home after authentication and onboarding
      redirect: (context, state) {
        final appState = context.read<AppState>();
        final authService = AuthService();
        final currentRoute = state.uri.path;

        Logger.debug('Redirect check for route: $currentRoute\n  isAuthAndProfilesReady: ${appState.isAuthAndProfilesReady}\n  isAuthenticated: ${authService.isSignedIn}\n  shouldShowOnboarding: ${appState.shouldShowOnboarding}\n  canAccessMainApp: ${appState.canAccessMainApp}\n  hasCompletedOnboarding: ${appState.hasCompletedOnboarding}', name: 'ROUTER');

        // Wait for both auth and profiles to be ready before making navigation decisions
        // This prevents race conditions where profiles haven't loaded yet
        if (!appState.isAuthAndProfilesReady) {
          Logger.debug('Auth and profiles not ready - waiting for initialization', name: 'ROUTER');
          return null;
        }

        // Check authentication status (after everything is ready)
        final isAuthenticated = authService.isSignedIn;

        // If not authenticated, redirect to splash/auth screen
        if (!isAuthenticated && currentRoute != AppRoutes.splash) {
          Logger.info('Not authenticated - redirecting to splash', name: 'ROUTER');
          return AppRoutes.splash;
        }

        // If authenticated but on splash, continue to next step
        if (isAuthenticated && currentRoute == AppRoutes.splash) {
          // Check if user needs onboarding
          if (appState.shouldShowOnboarding) {
            Logger.info('Authenticated but needs onboarding', name: 'ROUTER');
            return AppRoutes.onboarding;
          } else {
            Logger.info('Authenticated and onboarded - redirecting to home', name: 'ROUTER');
            return AppRoutes.home;
          }
        }

        // After auth, check onboarding for first-time users
        if (isAuthenticated &&
            appState.shouldShowOnboarding &&
            currentRoute != AppRoutes.onboarding) {
          Logger.info('Redirecting to onboarding (new user)', name: 'ROUTER');
          return AppRoutes.onboarding;
        }

        // Access main app after authentication and onboarding complete
        if (isAuthenticated &&
            appState.canAccessMainApp &&
            currentRoute == AppRoutes.onboarding) {
          Logger.info('Redirecting to home (onboarding complete)', name: 'ROUTER');
          return AppRoutes.home;
        }

        // If user hasn't completed onboarding, always show onboarding
        if (isAuthenticated &&
            !appState.hasCompletedOnboarding &&
            currentRoute != AppRoutes.onboarding &&
            currentRoute != AppRoutes.splash) {
          Logger.info('User needs onboarding - redirecting from $currentRoute', name: 'ROUTER');
          return AppRoutes.onboarding;
        }

        Logger.debug('No redirect needed - staying on $currentRoute', name: 'ROUTER');
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
            developer.log('📍 Navigated to Onboarding',
                name: 'Router.Navigate');
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
            // Home Screen (with Tutorial Overlay)
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              pageBuilder: (context, state) {
                developer.log('📍 Navigated to Home', name: 'Router.Navigate');

                return _buildPageWithTransition(
                  context,
                  state,
                  FutureBuilder<bool>(
                    future: TutorialService.shouldShowTutorial(),
                    builder: (context, snapshot) {
                      final shouldShowTutorial = snapshot.data ?? false;

                      if (!snapshot.hasData) {
                        // Show loading or just the screen while checking
                        return const HomeScreen();
                      }

                      developer.log(
                        '🎓 Tutorial should show: $shouldShowTutorial',
                        name: 'Router.Navigate',
                      );

                      return TutorialOverlay(
                        showTutorial: shouldShowTutorial,
                        child: const HomeScreen(),
                      );
                    },
                  ),
                );
              },
            ),

            // Profile Screen
            GoRoute(
              path: AppRoutes.profile,
              name: 'profile',
              pageBuilder: (context, state) {
                developer.log('📍 Navigated to Profile',
                    name: 'Router.Navigate');
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
                final entryId = state.uri.queryParameters['entryId'];
                developer.log(
                    entryId != null
                        ? '📍 Navigated to History with entry: $entryId'
                        : '📍 Navigated to History',
                    name: 'Router.Navigate');
                return _buildPageWithTransition(
                  context,
                  state,
                  HistoryScreen(initialEntryId: entryId),
                );
              },
            ),

            // Settings Screen
            GoRoute(
              path: AppRoutes.settings,
              name: 'settings',
              pageBuilder: (context, state) {
                developer.log('📍 Navigated to Settings',
                    name: 'Router.Navigate');
                return _buildPageWithTransition(
                  context,
                  state,
                  const SettingsScreen(),
                );
              },
            ),

            // Insights Screen
            GoRoute(
              path: AppRoutes.insights,
              name: 'insights',
              pageBuilder: (context, state) {
                developer.log('📍 Navigated to Insights',
                    name: 'Router.Navigate');
                return _buildPageWithTransition(
                  context,
                  state,
                  const InsightsScreen(),
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
          end: Offset.zero, // End at normal position
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
      transitionDuration:
          const Duration(milliseconds: AppDurations.pageTransition),
    );
  }
}
