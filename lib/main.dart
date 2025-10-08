/// Tap Card - NFC-enabled Digital Business Card Application
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
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/app_state.dart';
import 'core/navigation/app_router.dart';
import 'core/constants/widget_keys.dart';
import 'core/services/profile_service.dart';
import 'theme/theme.dart';

/// Application entry point
///
/// Initializes Flutter bindings, system UI configuration, and launches the app
void main() async {
  // Ensure Flutter is initialized before app starts
  WidgetsFlutterBinding.ensureInitialized();

  developer.log(
    '🚀 Tap Card app starting - Initializing system configuration',
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

  // Initialize ProfileService singleton for all screens
  developer.log(
    '🔧 Initializing ProfileService...',
    name: 'App.Main',
  );
  await ProfileService().initialize();
  developer.log(
    '✅ ProfileService initialized',
    name: 'App.Main',
  );

  developer.log(
    '✅ System configuration complete - Launching app',
    name: 'App.Main',
  );

  // TODO: Firebase - Initialize Firebase here
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const TapCardApp());
}

/// Root widget for Tap Card application
///
/// Manages global state, routing, and theme configuration
class TapCardApp extends StatefulWidget {
  const TapCardApp({super.key});

  @override
  State<TapCardApp> createState() => _TapCardAppState();
}

class _TapCardAppState extends State<TapCardApp> {
  /// Global router instance for navigation
  late final GoRouter _router;

  /// Global app state provider (onboarding, auth, etc.)
  late final AppState _appState;

  @override
  void initState() {
    super.initState();

    developer.log(
      '📱 Initializing app state and router',
      name: 'App.Init',
    );

    // Initialize global state and navigation
    _appState = AppState();
    _router = AppRouter.createRouter();

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
            title: 'Tap Card',
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
