import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/routes.dart';
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

class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: AppRoutes.splash,
      redirect: (context, state) {
        final appState = context.read<AppState>();
        final currentRoute = state.uri.path;

        // Wait for AppState to initialize before making navigation decisions
        if (!appState.isInitialized) {
          print('⏳ AppState not initialized yet, staying on current route');
          return null;
        }

        // Handle splash screen (for first launch)
        if (appState.shouldShowSplash && currentRoute != AppRoutes.splash) {
          print('🚀 Showing splash screen');
          return AppRoutes.splash;
        }

        // After splash, check onboarding for first-time users
        if (!appState.shouldShowSplash &&
            appState.shouldShowOnboarding &&
            currentRoute != AppRoutes.onboarding) {
          print('📚 Showing onboarding');
          return AppRoutes.onboarding;
        }

        // Access main app after onboarding complete
        if (!appState.shouldShowSplash &&
            appState.canAccessMainApp &&
            (currentRoute == AppRoutes.splash || currentRoute == AppRoutes.onboarding)) {
          print('🏠 Redirecting to home');
          return AppRoutes.home;
        }

        // If user hasn't completed onboarding, always show onboarding (except from onboarding itself)
        if (!appState.shouldShowSplash &&
            !appState.hasCompletedOnboarding &&
            currentRoute != AppRoutes.onboarding) {
          print('🎯 User needs onboarding - redirecting from $currentRoute');
          return AppRoutes.onboarding;
        }

        print('🔄 No redirect needed - staying on $currentRoute');
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutes.contactDetail,
          builder: (context, state) {
            final receivedContact = state.extra as ReceivedContact?;
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
        ShellRoute(
          builder: (context, state, child) => NavigationWrapper(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              pageBuilder: (context, state) => _buildPageWithTransition(
                context,
                state,
                const HomeScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.profile,
              pageBuilder: (context, state) => _buildPageWithTransition(
                context,
                state,
                const ProfileScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.history,
              pageBuilder: (context, state) => _buildPageWithTransition(
                context,
                state,
                const HistoryScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.settings,
              pageBuilder: (context, state) => _buildPageWithTransition(
                context,
                state,
                const SettingsScreen(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Page _buildPageWithTransition(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}