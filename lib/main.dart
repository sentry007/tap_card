/// Atlas Linq - NFC-enabled Digital Business Card Application
///
/// A modern Flutter application for sharing contact information via NFC,
/// featuring glassmorphism UI, multiple profile support, and real-time updates.
///
/// TODO: Firebase integration - Backend sync and cloud storage
/// TODO: Analytics - Track user engagement and sharing metrics
library;

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

  debugPrint('═══════════════════════════════════════════════════════');
  debugPrint('🚀 Atlas Linq app starting - Initializing system');
  debugPrint('═══════════════════════════════════════════════════════');

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
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');

    // Initialize Crashlytics for crash reporting (only in release/profile builds)
    if (kDebugMode) {
      debugPrint('🔧 DEBUG MODE: Crashlytics disabled - Crashes stay local');
    } else {
      debugPrint('📊 Initializing Crashlytics for release/profile build...');

      // Pass all uncaught Flutter errors to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      debugPrint('✅ Crashlytics initialized - Crash reporting enabled for beta/production');
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrint('   Stack trace: $stackTrace');
    debugPrint('   App will continue with local storage only');
  }

  // Wait for Firebase Auth to restore previous session
  // This ensures users stay logged in across app restarts
  try {
    debugPrint('🔐 Waiting for Firebase Auth state restoration...');

    final authStateRestored = await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );

    if (authStateRestored != null) {
      debugPrint('✅ Auth state restored: User signed in');
      debugPrint('   • UID: ${authStateRestored.uid}');
      debugPrint('   • Anonymous: ${authStateRestored.isAnonymous}');
      debugPrint('   • Provider: ${authStateRestored.providerData.isNotEmpty ? authStateRestored.providerData.first.providerId : "anonymous"}');
    } else {
      debugPrint('ℹ️  No auth session to restore - User will choose auth method on splash screen');
      // Don't auto-sign in here - let user choose on splash screen
      // This prevents creating anonymous accounts before user decides
    }
  } catch (e, stackTrace) {
    debugPrint('⚠️  Auth state restoration error - Continuing with app launch');
    debugPrint('   Error: $e');
  }

  // Initialize ProfileService singleton for all screens
  debugPrint('🔧 Initializing ProfileService...');

  try {
    await ProfileService().initialize();
    debugPrint('✅ ProfileService initialized');
  } catch (e, stackTrace) {
    debugPrint('❌ CRITICAL: ProfileService initialization failed - App may be unstable');
    debugPrint('   Error: $e');
    // Continue app launch - ProfileService will retry on auth events
    // User may see errors until profiles are created
  }

  // Initialize TutorialService for interactive onboarding
  debugPrint('🎓 Initializing TutorialService...');
  await TutorialService.initialize();
  debugPrint('✅ TutorialService initialized');

  debugPrint('═══════════════════════════════════════════════════════');
  debugPrint('✅ System configuration complete - Launching app');
  debugPrint('═══════════════════════════════════════════════════════');

  runApp(const AtlasLinqApp());

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
    debugPrint('✅ App state initialized in ${duration}ms');
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
    debugPrint('🛑 App disposing - Cleaning up resources');
    // AppState and Router are disposed automatically by framework
    super.dispose();
  }
}
