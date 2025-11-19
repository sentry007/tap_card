/// Atlas Linq - NFC-enabled Digital Business Card Application
///
/// A modern Flutter application for sharing contact information via NFC,
/// featuring glassmorphism UI, multiple profile support, and real-time updates.
///
/// TODO: Firebase integration - Backend sync and cloud storage
/// TODO: Analytics - Track user engagement and sharing metrics
library;

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

import 'core/providers/app_state.dart';
import 'core/navigation/app_router.dart';
import 'core/constants/widget_keys.dart';
import 'core/services/profile_service.dart';
import 'services/tutorial_service.dart';
import 'theme/theme.dart';
import 'utils/logger.dart';

/// Application entry point
///
/// Initializes Flutter bindings, system UI configuration, and launches the app
void main() async {
  // Ensure Flutter is initialized before app starts
  WidgetsFlutterBinding.ensureInitialized();

  developer.log(
    '🚀 Atlas Linq app starting - Initializing system configuration',
    name: 'App.Main',
  );

  // Configure system UI overlay for immersive experience
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lock orientation to portrait for consistent UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  try {
    developer.log(
      '🔥 Initializing Firebase...',
      name: 'App.Main',
    );
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log(
      '✅ Firebase initialized successfully',
      name: 'App.Main',
    );

    // Initialize Crashlytics for crash reporting
    developer.log(
      '📊 Initializing Crashlytics...',
      name: 'App.Main',
    );

    // Pass all uncaught Flutter errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    developer.log(
      '✅ Crashlytics initialized - Crash reporting enabled',
      name: 'App.Main',
    );
  } catch (e, stackTrace) {
    developer.log(
      '❌ Firebase initialization failed - App will continue with local storage only',
      name: 'App.Main',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Wait for Firebase Auth to restore previous session
  // This ensures users stay logged in across app restarts
  try {
    developer.log(
      '🔐 Waiting for Firebase Auth state restoration...',
      name: 'App.Main',
    );

    final authStateRestored = await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );

    if (authStateRestored != null) {
      developer.log(
        '✅ Auth state restored: User signed in\n'
        '   • UID: ${authStateRestored.uid}\n'
        '   • Anonymous: ${authStateRestored.isAnonymous}\n'
        '   • Provider: ${authStateRestored.providerData.isNotEmpty ? authStateRestored.providerData.first.providerId : "anonymous"}',
        name: 'App.Main',
      );
    } else {
      developer.log(
        'ℹ️  No auth session to restore - User will choose auth method on splash screen',
        name: 'App.Main',
      );
      // Don't auto-sign in here - let user choose on splash screen
      // This prevents creating anonymous accounts before user decides
    }
  } catch (e, stackTrace) {
    developer.log(
      '⚠️  Auth state restoration error - Continuing with app launch',
      name: 'App.Main',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Initialize ProfileService singleton for all screens
  developer.log(
    '🔧 Initializing ProfileService...',
    name: 'App.Main',
  );

  try {
    await ProfileService().initialize();
    developer.log(
      '✅ ProfileService initialized',
      name: 'App.Main',
    );
  } catch (e, stackTrace) {
    developer.log(
      '❌ CRITICAL: ProfileService initialization failed - App may be unstable',
      name: 'App.Main',
      error: e,
      stackTrace: stackTrace,
    );
    // Continue app launch - ProfileService will retry on auth events
    // User may see errors until profiles are created
  }

  // Initialize TutorialService for interactive onboarding
  developer.log(
    '🎓 Initializing TutorialService...',
    name: 'App.Main',
  );
  await TutorialService.initialize();
  developer.log(
    '✅ TutorialService initialized',
    name: 'App.Main',
  );

  developer.log(
    '✅ System configuration complete - Launching app',
    name: 'App.Main',
  );

  runApp(const AtlasLinqApp());
}

/// Root widget for Atlas Linq application
///
/// Manages global state, routing, and theme configuration
class AtlasLinqApp extends StatefulWidget {
  const AtlasLinqApp({super.key});

  @override
  State<AtlasLinqApp> createState() => _AtlasLinqAppState();
}

class _AtlasLinqAppState extends State<AtlasLinqApp> {
  /// Global router instance for navigation
  late final GoRouter _router;

  /// Global app state provider (onboarding, auth, etc.)
  late final AppState _appState;

  @override
  void initState() {
    super.initState();

    Logger.info('Initializing app state and router', name: 'MAIN');

    // Initialize global state first
    _appState = AppState();

    // Create router with AppState so it can listen to auth/profile changes
    _router = AppRouter.createRouter(_appState);

    Logger.info('Router created with AppState as refreshListenable', name: 'MAIN');

    // Load persisted state from storage
    _initializeAppState();
  }

  /// Initialize app state from persistent storage
  ///
  /// Loads user preferences, onboarding status, and authentication state
  /// TODO: Firebase - Sync user state from Firestore if authenticated
  Future<void> _initializeAppState() async {
    final startTime = DateTime.now();

    await _appState.initializeFromStorage();

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    developer.log(
      '✅ App state initialized in ${duration}ms',
      name: 'App.Init',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      key: WidgetKeys.appMultiProvider,
      providers: [
        // Global app state (onboarding, auth, navigation flow)
        ChangeNotifierProvider.value(value: _appState),

        // TODO: Firebase - Add Firebase providers here
        // Provider<FirebaseAuth>(create: (_) => FirebaseAuth.instance),
        // Provider<FirebaseFirestore>(create: (_) => FirebaseFirestore.instance),
      ],
      child: Consumer<AppState>(
        key: WidgetKeys.appStateConsumer,
        builder: (context, appState, child) {
          return MaterialApp.router(
            key: WidgetKeys.appMaterialRouter,
            title: 'Atlas Linq',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routerConfig: _router,
            builder: (context, child) {
              // Ensure system UI overlay remains consistent across screens
              return AnnotatedRegion<SystemUiOverlayStyle>(
                key: WidgetKeys.appSystemUiRegion,
                value: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  systemNavigationBarColor: AppColors.primaryBackground,
                  systemNavigationBarIconBrightness: Brightness.light,
                ),
                child: child ?? const SizedBox(key: WidgetKeys.appFallbackBox),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    developer.log(
      '🛑 App disposing - Cleaning up resources',
      name: 'App.Dispose',
    );
    // AppState and Router are disposed automatically by framework
    super.dispose();
  }
}
