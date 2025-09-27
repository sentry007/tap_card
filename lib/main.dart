import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/app_state.dart';
import 'core/navigation/app_router.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const TapCardApp());
}

class TapCardApp extends StatefulWidget {
  const TapCardApp({Key? key}) : super(key: key);

  @override
  State<TapCardApp> createState() => _TapCardAppState();
}

class _TapCardAppState extends State<TapCardApp> {
  late GoRouter _router;
  late AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _router = AppRouter.createRouter();
    _initializeAppState();
  }

  Future<void> _initializeAppState() async {
    await _appState.initializeFromStorage();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      key: const Key('app_multi_provider'),
      providers: [
        ChangeNotifierProvider.value(value: _appState),
      ],
      child: Consumer<AppState>(
        key: const Key('app_state_consumer'),
        builder: (context, appState, child) {
          return MaterialApp.router(
            key: const Key('app_material_router'),
            title: 'Tap Card',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routerConfig: _router,
            builder: (context, child) {
              return AnnotatedRegion<SystemUiOverlayStyle>(
                key: const Key('app_system_ui_region'),
                value: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  systemNavigationBarColor: AppColors.primaryBackground,
                  systemNavigationBarIconBrightness: Brightness.light,
                ),
                child: child ?? const SizedBox(key: Key('app_fallback_box')),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
